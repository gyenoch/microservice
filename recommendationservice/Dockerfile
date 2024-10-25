FROM python:3.10.13-slim as base

FROM base as builder
WORKDIR /app
# get packages
COPY requirements.txt /app/         

RUN pip install -r requirements.txt

FROM base
# Enable unbuffered logging
ENV PYTHONUNBUFFERED=1
# Disable Profiler
ENV DISABLE_PROFILER=1

WORKDIR /app

# Grab packages from builder
COPY --from=builder /usr/local/lib/python3.10/ /usr/local/lib/python3.10/

# Add the application
COPY *.py /app/

ENV PRODUCT_CATALOG_SERVICE_ADDR=productcatalogservice:3550

ENV PORT "8080"

EXPOSE 8080

ENTRYPOINT [ "python", "recommendation_server.py" ]
