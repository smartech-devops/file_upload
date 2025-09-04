# Network Architecture Design

## Overview

The CSV processor application uses a multi-VPC architecture with VPC peering to separate concerns between compute (Lambda) and database (RDS) resources while maintaining secure communication.

## Architecture Components

### VPCs

#### Lambda VPC
- **CIDR Block**: `10.0.0.0/16`
- **Purpose**: Hosts Lambda functions and related compute resources
- **DNS**: Enabled (hostnames and support)

#### RDS VPC
- **CIDR Block**: `10.1.0.0/16`
- **Purpose**: Hosts RDS PostgreSQL database
- **DNS**: Enabled (hostnames and support)

### Subnets

#### Lambda VPC Subnets
- **Private Subnets**:
  - `lambda-private-a`: `10.0.1.0/24` (AZ-0)
  - `lambda-private-b`: `10.0.2.0/24` (AZ-1)
- **Public Subnets**:
  - `lambda-public-a`: `10.0.3.0/24` (AZ-0)
  - `lambda-public-b`: `10.0.4.0/24` (AZ-1)

#### RDS VPC Subnets
- **Private Subnets**:
  - `rds-private-a`: `10.1.1.0/24` (AZ-0)
  - `rds-private-b`: `10.1.2.0/24` (AZ-1)
- **Public Subnets**:
  - `rds-public-a`: `10.1.3.0/24` (AZ-0)
  - `rds-public-b`: `10.1.4.0/24` (AZ-1)

### Internet Connectivity

#### Internet Gateways
- **Lambda IGW**: Provides internet access to Lambda VPC public subnets (for management)
- **RDS IGW**: Provides internet access to RDS VPC public subnets (for management)

#### Route Tables
- **Lambda Public Route Table**:
  - `0.0.0.0/0` → Lambda IGW (internet access)
  - `10.1.0.0/16` → VPC Peering Connection (RDS VPC access)
- **Lambda Private Route Table**:
  - `10.1.0.0/16` → VPC Peering Connection (RDS VPC access)
  - S3 Gateway Endpoint routes (managed automatically)
- **RDS Public Route Table**:
  - `0.0.0.0/0` → RDS IGW (internet access)
- **RDS Private Route Table**:
  - `10.0.0.0/16` → VPC Peering Connection (Lambda VPC access)

### VPC Peering

#### Lambda ↔ RDS Peering
- **Connection**: Bidirectional VPC peering between Lambda and RDS VPCs
- **Auto Accept**: Enabled
- **DNS Resolution**: Accepter VPC allows requester VPC DNS resolution
- **Purpose**: Allows Lambda functions to communicate with RDS database
- **Routes**:
  - Lambda VPC can reach `10.1.0.0/16` (RDS VPC)
  - RDS VPC can reach `10.0.0.0/16` (Lambda VPC)

### VPC Endpoints (AWS PrivateLink)

#### S3 Gateway Endpoint
- **Type**: Gateway Endpoint (no additional cost)
- **Associated Route Tables**: Lambda Private Route Table
- **Purpose**: Private S3 access for Lambda functions
- **Services**: All S3 operations (GetObject, PutObject, CopyObject, ListBucket)

#### Secrets Manager Interface Endpoint
- **Type**: Interface Endpoint with ENI
- **Subnets**: Lambda private subnets (both AZs)
- **Security Group**: VPC Endpoints Security Group
- **Private DNS**: Enabled
- **Purpose**: Secure database credential retrieval
- **Cost**: ~$7.20/month + data processing charges

#### SNS Interface Endpoint
- **Type**: Interface Endpoint with ENI
- **Subnets**: Lambda private subnets (both AZs)
- **Security Group**: VPC Endpoints Security Group
- **Private DNS**: Enabled
- **Purpose**: Email notifications via SNS
- **Cost**: ~$7.20/month + data processing charges

### Security Groups

#### Lambda Security Group
- **Egress**: All traffic allowed (`0.0.0.0/0`)
- **Purpose**: Allows Lambda functions to make outbound connections to VPC endpoints and RDS

#### RDS Security Group
- **Ingress**: PostgreSQL (port 5432) from Lambda VPC (`10.0.0.0/16`)
- **Egress**: All traffic allowed (`0.0.0.0/0`)
- **Purpose**: Restricts database access to Lambda functions only

#### VPC Endpoints Security Group
- **Ingress**: HTTPS (port 443) from Lambda Security Group
- **Egress**: All traffic allowed (`0.0.0.0/0`)
- **Purpose**: Allows Lambda to access VPC endpoints securely

## High Availability Design

### Multi-AZ Deployment
- **Subnets**: All subnet types (private/public) span across 2 availability zones
- **Benefits**:
  - Fault tolerance if one AZ becomes unavailable
  - Load balancer support (requires multi-AZ public subnets)
  - NAT Gateway HA potential (can deploy NAT in each AZ)

### Database Subnet Group
- **Subnets**: Uses both RDS private subnets (`rds-private-a`, `rds-private-b`)
- **Purpose**: Enables RDS Multi-AZ deployment

## Security Considerations

### Network Isolation
- **Separation**: Lambda and RDS resources are isolated in separate VPCs
- **Communication**: Only specific routes through VPC peering
- **Database Access**: RDS only accessible from Lambda VPC CIDR

### Private Placement
- **Lambda**: Deployed in private subnets (no direct internet access)
- **RDS**: Deployed in private subnets (database isolation)
- **VPC Endpoints**: Interface endpoints in private subnets
- **Public Subnets**: Available for management resources, load balancers, bastion hosts

### Traffic Flow (Updated Architecture)
1. **S3 Trigger**: S3 Event → Lambda (private subnet)
2. **Lambda-S3**: Lambda → S3 Gateway Endpoint (private)
3. **Lambda-Secrets**: Lambda → Secrets Manager VPC Endpoint (private)
4. **Lambda-RDS**: Lambda (private subnet) → VPC Peering → RDS (private subnet)
5. **Lambda-SNS**: Lambda → SNS VPC Endpoint (private)
6. **No Internet**: Lambda has no internet access - all AWS services via VPC endpoints

## Scalability Features

### Auto Scaling Support
- **Lambda**: Can scale across multiple AZs
- **Load Balancing**: Public subnets support ALB/NLB deployment
- **Database**: RDS can be configured for read replicas across AZs

### Current Enhancements Implemented
- **VPC Endpoints**: ✅ S3, Secrets Manager, and SNS endpoints for private AWS access
- **Private DNS**: ✅ Enabled for automatic DNS resolution to VPC endpoints
- **Enhanced Security**: ✅ No internet access required for Lambda functions

### Future Enhancements
- **NAT Gateways**: Can be added if external internet access is needed
- **Additional VPC Endpoints**: CloudWatch Logs, Lambda API for enhanced monitoring
- **Additional VPCs**: Architecture supports adding more VPCs with peering connections
- **Transit Gateway**: For complex multi-VPC architectures

## Network Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────┐    ┌──────────────────────────┐  │
│  │              Lambda VPC                 │    │         RDS VPC          │  │
│  │            (10.0.0.0/16)                │    │      (10.1.0.0/16)      │  │
│  │                                         │    │                          │  │
│  │  ┌─────────────────────────────────┐   │    │  ┌─────────────────────┐ │  │
│  │  │         Public Subnets          │   │    │  │    Public Subnets   │ │  │
│  │  │  ┌─────────────┬─────────────┐  │   │    │  │  ┌─────────────────┐ │ │  │
│  │  │  │10.0.3.0/24  │10.0.4.0/24  │  │   │    │  │  │10.1.3.0/24-    │ │ │  │
│  │  │  │   (AZ-0)    │   (AZ-1)    │  │   │    │  │  │10.1.4.0/24     │ │ │  │
│  │  │  └─────────────┴─────────────┘  │   │    │  │  └─────────────────┘ │ │  │
│  │  └─────────────────────────────────┘   │    │  └─────────────────────┘ │  │
│  │              │                         │    │              │           │  │
│  │        [Internet Gateway]              │    │        [Internet Gateway]│  │
│  │              │                         │    │              │           │  │
│  │  ┌─────────────────────────────────┐   │    │  ┌─────────────────────┐ │  │
│  │  │         Private Subnets         │   │    │  │   Private Subnets   │ │  │
│  │  │  ┌─────────────┬─────────────┐  │   │◄──►│  │  ┌─────────────────┐ │ │  │
│  │  │  │10.0.1.0/24  │10.0.2.0/24  │  │   │    │  │  │10.1.1.0/24-    │ │ │  │
│  │  │  │   (AZ-0)    │   (AZ-1)    │  │   │    │  │  │10.1.2.0/24     │ │ │  │
│  │  │  │   [Lambda]  │   [Lambda]  │  │   │    │  │  │     [RDS]       │ │ │  │
│  │  │  │             │             │  │   │    │  │  └─────────────────┘ │ │  │
│  │  │  │  ┌─────────────────────────┤  │   │    │  └─────────────────────┘ │  │
│  │  │  │  │   VPC Endpoints         │  │   │    │                          │  │
│  │  │  │  │ • S3 (Gateway)          │  │   │    │                          │  │
│  │  │  │  │ • Secrets Mgr (ENI)     │  │   │    │                          │  │
│  │  │  │  │ • SNS (ENI)             │  │   │    │                          │  │
│  │  │  │  │ • Private DNS Enabled   │  │   │    │                          │  │
│  │  │  │  └─────────────────────────┤  │   │    │                          │  │
│  │  │  └─────────────┴─────────────┘  │   │    │                          │  │
│  │  └─────────────────────────────────┘   │    │                          │  │
│  │                                         │    │                          │  │
│  │              ▲                         │    │                          │  │
│  │              │ Private AWS Network     │    │                          │  │
│  │         ┌────┴────┐                    │    │                          │  │
│  │         │   S3    │ (Trigger)          │    │                          │  │
│  │         │ Buckets │                    │    │                          │  │
│  │         └─────────┘                    │    │                          │  │
│  └─────────────────────────────────────────┘    └──────────────────────────┘  │
│                               VPC Peering (DNS Resolution Enabled)           │
└─────────────────────────────────────────────────────────────────────────────┘

Traffic Flow (All Private):
Lambda → S3: Via Gateway Endpoint
Lambda → Secrets Manager: Via Interface Endpoint + Private DNS
Lambda → RDS: Via VPC Peering
Lambda → SNS: Via Interface Endpoint + Private DNS
```

## Resource Naming Convention

- **VPCs**: `csv-processor-{service}-vpc`
- **Subnets**: `csv-processor-{service}-{type}-{az}`
- **Route Tables**: `csv-processor-{service}-{type}-rt`
- **Security Groups**: `csv-processor-{service}-sg`
- **Internet Gateways**: `csv-processor-{service}-igw`

## Monitoring and Logging

### VPC Flow Logs
- Can be enabled for traffic monitoring
- Useful for security analysis and troubleshooting

### Network ACLs
- Currently using default NACLs
- Can be customized for additional security layers

---

*This document reflects the current network architecture as implemented in the Terraform modules.*