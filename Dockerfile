# Use Alpine-based Node.js image
FROM node:18-alpine

# Set working directory inside the container
WORKDIR /app

# Copy only dependency files first (for caching)
COPY package*.json ./

# Install build dependencies required for native modules
RUN apk add --no-cache \
      python3 \
      make \
      g++ \
  && npm cache clean --force \
  && npm install --legacy-peer-deps --loglevel=error \
  && apk del python3 make g++

# Copy the rest of the application code
COPY . .

# Expose the port (adjust if different)
EXPOSE 3000

# Start the application
CMD ["npm", "start"]
