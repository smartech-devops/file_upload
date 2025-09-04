# Test Sample Data

This directory contains sample CSV files for testing various scenarios:

## Files

### `valid-sample.csv`
- **Purpose**: Well-formed CSV with standard data types
- **Records**: 10 employee records
- **Columns**: id, first_name, last_name, email, age, department, salary, hire_date, active
- **Use Case**: Validates normal CSV processing functionality

### `invalid-sample.csv`
- **Purpose**: CSV with various data validation issues
- **Records**: 10 records with different types of invalid data
- **Issues Tested**:
  - Invalid email formats
  - Non-numeric age values
  - Invalid salary formats
  - Invalid date formats
  - Missing required fields
  - Negative age values
- **Use Case**: Tests error handling and data validation

### `large-sample.csv`
- **Purpose**: CSV with longer text content
- **Records**: 10 records with detailed descriptions
- **Columns**: id, name, email, department, description
- **Use Case**: Tests handling of larger text fields and content processing

### `special-characters.csv`
- **Purpose**: CSV with Unicode and special characters
- **Records**: 6 records with international names and locations
- **Character Sets**: UTF-8 encoded with various languages (Portuguese, German, Chinese, Russian, Norwegian, French)
- **Use Case**: Tests Unicode handling and character encoding

### `empty-sample.csv`
- **Purpose**: CSV file with only headers, no data rows
- **Records**: 0 data records (header only)
- **Use Case**: Tests handling of empty files and edge cases

## Usage

These sample files can be used for:

1. **Manual Testing**: Upload files directly to S3 input bucket for testing
2. **Automated Testing**: Used by test scripts for validation scenarios
3. **Development**: Reference files for understanding expected input formats

## Testing Scenarios

- **Happy Path**: Use `valid-sample.csv`
- **Error Handling**: Use `invalid-sample.csv`
- **Large Content**: Use `large-sample.csv` 
- **Internationalization**: Use `special-characters.csv`
- **Edge Cases**: Use `empty-sample.csv`