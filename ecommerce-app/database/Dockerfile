# Use the official MySQL 8.0 base image
FROM mysql:8.0

# Copy our init.sql file into the automatic execution folder of MySQL
COPY init.sql /docker-entrypoint-initdb.d/

# Expose the default MySQL port
EXPOSE 3306
