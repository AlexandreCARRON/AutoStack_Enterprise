ARG DEMO_API_IMAGE=python:3.12-slim-bookworm
FROM ${DEMO_API_IMAGE}

RUN useradd --create-home --uid 10001 demo
WORKDIR /app
COPY --chown=demo:demo server.py /app/server.py

USER demo
EXPOSE 8080 8443
ENTRYPOINT ["python", "/app/server.py"]
