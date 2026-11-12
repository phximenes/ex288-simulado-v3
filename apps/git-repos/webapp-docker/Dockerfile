FROM registry.access.redhat.com/ubi9/nodejs-22-minimal:latest
ARG NPM_REGISTRY=https://registry.npmjs.org/
WORKDIR /opt/app-root/src
COPY --chown=1001:0 package.json server.js ./
RUN npm config set registry "${NPM_REGISTRY}" && npm install --omit=dev
EXPOSE 8080
USER 1001
CMD ["node", "server.js"]
