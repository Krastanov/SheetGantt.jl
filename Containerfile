FROM docker.io/library/julia:1.12.7-trixie

WORKDIR /app
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/*

COPY . .
RUN julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
ENV GENIE_ENV=prod
EXPOSE 8000
ENTRYPOINT ["./bin/server"]
