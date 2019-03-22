FROM node:10.15.2

# Run this from rainblock-storage dir
COPY rainblock-storage.zip /home/node/rainblock-storage.zip
RUN cd /home/node/ && unzip rainblock-storage.zip

WORKDIR /home/node/rainblock-storage

RUN chown -R node:node /home/node/rainblock-storage

USER node

RUN ls -al
RUN pwd
RUN npm install
RUN npm run prepare
RUN npm run test

RUN ls src
CMD [ "node","-r","ts-node/register","src/server.ts", "-1", "50051" ]
