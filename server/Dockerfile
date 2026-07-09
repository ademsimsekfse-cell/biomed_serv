FROM node:18-alpine

# Create app directory
WORKDIR /usr/src/app

# Install app dependencies
COPY server/package.json server/package-lock.json ./
RUN npm ci --only=production

# Bundle app source
COPY server .

RUN npm run build

EXPOSE 3000
CMD ["node","dist/main.js"]
