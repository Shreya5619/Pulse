# Use Node 20
FROM node:20-alpine

WORKDIR /app

# Copy package files for both root and server
COPY package*.json ./
COPY server/package*.json ./server/

# Install dependencies
RUN npm install
RUN cd server && npm install

# Copy entire project (needed because server imports from agents/ and memory/)
COPY . .

# Build the server
WORKDIR /app/server
RUN npm run build

# Expose port
EXPOSE 8080

# Environment variables defaults
ENV NODE_ENV=production
ENV PULSE_HTTP_PORT=8080
ENV PULSE_HTTP_HOST=0.0.0.0

# Start server
CMD ["npm", "start"]
