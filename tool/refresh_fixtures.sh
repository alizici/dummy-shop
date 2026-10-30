#!/usr/bin/env bash
# Re-downloads the real DummyJSON responses used as test fixtures.
# The tests read these files as they are, so a change in the API shows up as a failing test.
set -euo pipefail
cd "$(dirname "$0")/../test/fixtures"
fields="id,title,category,price,discountPercentage,rating,stock,thumbnail,brand"
curl -fsS "https://dummyjson.com/products?limit=3&skip=0&select=$fields" | python3 -m json.tool > products_page.json
curl -fsS "https://dummyjson.com/products/1" | python3 -m json.tool > product_1.json
echo "fixtures refreshed: $(ls *.json | tr '\n' ' ')"
