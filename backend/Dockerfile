FROM node:14
WORKDIR /app 

# Copy the package files first
COPY package*.json ./ 

# Then install dependencies
RUN npm install

# Copy the rest of your backend code
COPY . . 

EXPOSE 3000
CMD ["node", "server.js"]
