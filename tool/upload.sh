#!/usr/bin/env bash
set -e
pub build
cp -R build/web/* ~/Work/get-dsa/
pushd ~/Work/get-dsa/
git add .
git commit -m "Update Build"
git push origin gh-pages
popd
