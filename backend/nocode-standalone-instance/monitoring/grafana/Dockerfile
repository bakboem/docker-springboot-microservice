FROM grafana/grafana:latest
USER root
COPY grafana_public_key.pem /etc/grafana/grafana_public_key.pem
RUN chown 472:472 /etc/grafana/grafana_public_key.pem
ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
USER 472
