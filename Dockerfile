# Use Debian-based Node.js image for better compatibility
FROM node:18-slim

# Set working directory inside the container
WORKDIR /app

# Copy only dependency files first (for caching)
COPY package*.json ./

# Install app dependencies
# --force helps resolve peer dep conflicts and ensures ajv compatibility
RUN npm install --force --loglevel=error

# Copy the full application code
COPY . .

# Expose the port your app uses (React dev server default)
EXPOSE 5000

# Start the application
ENV PORT=5000
CMD ["npm", "start"]
