#!/bin/sh
sed "s|__MATRIX_DOMAIN__|${MATRIX_DOMAIN}|g" /app/config.template.json > /app/config.json