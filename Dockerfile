FROM node:8

ADD ./ /usr/blog-dependency
# Create app directory
WORKDIR /usr/blog-dependency

# RUN npm install
RUN npm install

WORKDIR /usr/blog

EXPOSE 4000

CMD [ "cp", "-r", "/usr/blog-dependency/node_modules", "/usr/blog/node_modules" ]
CMD [ "npm", "run", "generate" ]
CMD [ "npm", "run", "serve" ]
