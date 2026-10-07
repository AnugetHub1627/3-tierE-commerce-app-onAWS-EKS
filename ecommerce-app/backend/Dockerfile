# Step 1: Use an official Node.js runtime as the base image
FROM node:18-alpine

# Step 2: Set the working directory inside the container
WORKDIR /usr/src/app

# Step 3: Copy package config and install dependencies
COPY package*.json ./
RUN npm install

# Step 4: Copy the rest of your backend code
COPY . .

# Step 5: Expose the port your backend runs on
EXPOSE 5000

# Step 6: Start the server
CMD ["npm", "start"]
