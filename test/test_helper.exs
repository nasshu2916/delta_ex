# Cloud storage integration tests are excluded by default. Run them with:
#
#     docker compose up -d minio minio-setup
#     mix test --include s3
#
ExUnit.start(exclude: [:s3])
