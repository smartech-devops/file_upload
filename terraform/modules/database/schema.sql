-- Database schema for CSV Processor
-- This script creates the required tables for the application

-- Create file_metadata table
CREATE TABLE IF NOT EXISTS file_metadata (
    id SERIAL PRIMARY KEY,
    filename VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL,
    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create index on filename for faster lookups
CREATE INDEX IF NOT EXISTS idx_file_metadata_filename ON file_metadata(filename);

-- Create index on timestamp for time-based queries
CREATE INDEX IF NOT EXISTS idx_file_metadata_timestamp ON file_metadata(timestamp);

-- Create index on status for filtering
CREATE INDEX IF NOT EXISTS idx_file_metadata_status ON file_metadata(status);