# Step 1: Build the React application
FROM node:18-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Step 2: Serve the build files using Nginx (lightweight web server)
FROM nginx:alpine
# Copy the production build files from Step 1 to Nginx public folder
COPY --from=build /app/build /usr/share/nginx/html
# Expose port 80 (standard HTTP port)
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
