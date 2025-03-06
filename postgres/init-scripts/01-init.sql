-- Create a schema for IoT data
CREATE SCHEMA IF NOT EXISTS iot;

-- Create a table for sensor data
CREATE TABLE IF NOT EXISTS iot.sensor_data (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    sensor_type VARCHAR(50) NOT NULL,
    value DECIMAL NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX idx_device_id ON iot.sensor_data(device_id);
CREATE INDEX idx_timestamp ON iot.sensor_data(timestamp);