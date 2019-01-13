FROM node:8

ADD ./ /usr/blog
# Create app directory
WORKDIR /usr/blog

# RUN npm install
RUN npm install

EXPOSE 4000

CMD [ "npm", "run", "generate" ]
CMD [ "npm", "run", "serve" ]
