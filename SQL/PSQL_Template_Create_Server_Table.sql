--Create a schema named scans
CREATE SCHEMA scans;

--Create a database named MyDatabase
CREATE DATABASE MyDatabase;

--Switch to the MyDatabase database
\c MyDatabase;

--Create a table named Servers within the scans schema
CREATE TABLE scans.Servers (
    Servername varchar(15),
    Description varchar(140),
    IPv4Address varchar(16),
    DNSHostName varchar(80),
    OperatingSystem varchar(80),
    ScanDate TIMESTAMP,
    PRIMARY KEY (Servername, ScanDate)
);
