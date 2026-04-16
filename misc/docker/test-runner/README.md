# Docker test runner

The image is intentionally based on Debian 8 / Jessie to stay close to the target environment.
Because Jessie is end-of-life, Java 11 and Maven are installed manually in the container instead of relying on a modern Maven base image.

Build the image:

```bash
docker build -t activity-manager-tests misc/docker/test-runner
```

This build currently starts from `debian/eol:jessie`.

Run the core Tycho tests from the repository root:

```bash
docker run --rm \
  -v "$(pwd -W):/workspace" \
  -v activity-manager-m2:/m2 \
  activity-manager-tests
```

Run a single test pattern:

```bash
docker run --rm \
  -v "$PWD:/workspace" \
  -v activity-manager-m2:/m2 \
  activity-manager-tests \
  -Dtycho.tests.patterns=**/TaskTest.java \
  -DfailIfNoTests=false
```

Useful environment variables:

```text
TP_MODE=build
TEST_MODULE=core/tests/org.activitymgr.core.tests
WORKSPACE_DIR=/workspace
M2_DIR=/m2/repository
```

Notes:

- The script installs `parent/tpd` first because the Tycho test module resolves the target platform from that local artifact.
- The script then runs a root `install` with `-Dmaven.test.skip=true` so Tycho fragments are present in the local Maven repository before the test phase.
- Tests are finally launched from the root reactor with `-pl core/tests/org.activitymgr.core.tests -am` and `verify`, which is required for Tycho `eclipse-test-plugin` execution.
- `-Dgit.dirty=ignore` is passed on purpose so local work-in-progress does not block the build.
- Maven dependencies are cached in the named Docker volume `activity-manager-m2`.
- The Dockerfile downloads a Java 11 JDK from Eclipse Adoptium and Maven 3.9.9 during image build time.

Run the same tests against MySQL 5.5.47:

```bash
docker compose -f misc/docker/test-runner/compose.mysql55.yml up --build --abort-on-container-exit tests
```

Stop the stack:

```bash
docker compose -f misc/docker/test-runner/compose.mysql55.yml down -v
```

Notes for the MySQL scenario:

- The `tests` service keeps using the same runner image and script.
- The MySQL-specific JDBC settings are injected through environment variables, so the default H2 configuration remains unchanged outside Compose.
- The `mysql55` service installs MySQL from the official Debian Jessie repositories to stay close to a standard Jessie setup.

Run the tests with a Debian 12 runner and MySQL 8:

```bash
docker compose -f misc/docker/test-runner/compose.mysql8.yml up --build --abort-on-container-exit tests
```

Stop that stack:

```bash
docker compose -f misc/docker/test-runner/compose.mysql8.yml down -v
```

Notes for the Debian 12 / MySQL 8 scenario:

- The test runner uses `Dockerfile.debian12` and keeps the same Java 11 + Maven bootstrap approach.
- The MySQL service uses the official `mysql:8.0` image with `mysql_native_password` enabled to keep the test setup compatible with the current JDBC configuration.

Run the tests with a full Debian 12 + MariaDB stack:

```bash
docker compose -f misc/docker/test-runner/compose.mariadb12.yml up --build --abort-on-container-exit tests
```

Stop that stack:

```bash
docker compose -f misc/docker/test-runner/compose.mariadb12.yml down -v
```

Notes for the Debian 12 / MariaDB scenario:

- Both the runner and the database services are built from Debian 12 images.
- The database service installs `mariadb-server` from the official Debian 12 repositories.
- The MariaDB stack now uses the native MariaDB JDBC driver and a `jdbc:mariadb://...` URL.
