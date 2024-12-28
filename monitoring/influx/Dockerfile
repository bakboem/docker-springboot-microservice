FROM influxdb:2.7-alpine
# Copy the entrypoint script
COPY ./entrypoint.sh /entrypoint.sh
ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
# Install netcat using apk
RUN apk update \
    && apk add --no-cache netcat-openbsd \
    && apk add --no-cache curl \
    && apk add --no-cache jq \
    && chmod +x /entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Expose the InfluxDB port
EXPOSE 8086

