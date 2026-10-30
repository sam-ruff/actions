FROM scratch
COPY --chmod=0755 dist/hello-fixture-linux-amd64 /hello-fixture
USER 65532:65532
ENTRYPOINT ["/hello-fixture"]
