# Unlimited OnlyOffice Build Script  

This script builds the unlimited OnlyOffice Docker images. The following repositories are used in the build process:  

1. [btactic-oo/unlimited-onlyoffice-package-builder](https://github.com/btactic-oo/unlimited-onlyoffice-package-builder.git)  
2. [thomisus/Docker-DocumentServer](https://github.com/thomisus/Docker-DocumentServer.git)  

## Building Images  
This script builds images based on the provided version. Run the following command to start the build:  

```bash
bash unlimited_onlyoffice_build.sh "release/v8.3.0"
```  

## Known Issues  

1. **Hardcoded `BUILD_VERSION` and `BUILD_NUMBER`**  
   Currently, `BUILD_VERSION` and `BUILD_NUMBER` are hardcoded because they are not being passed inside the Docker environment.  

   ```bash
   docker_exec oo-deb-builder "cd / && git clone https://github.com/ONLYOFFICE/document-server-package.git"
   docker_exec oo-deb-builder "cd /document-server-package && git checkout $BUILD_BRANCH"
   docker_exec oo-deb-builder "cd /document-server-package && \
       echo 'deb_dependencies: \$(DEB_DEPS)' >> Makefile"
   docker_exec oo-deb-builder "cd /document-server-package && \
       PRODUCT_VERSION="8.3.0" BUILD_NUMBER="1-xyz" make deb_dependencies"
   docker_exec oo-deb-builder "cd /document-server-package/deb/build && apt-get -qq build-dep -y ./"
   docker_exec oo-deb-builder "cd /document-server-package && \
       PRODUCT_VERSION="8.3.0" BUILD_NUMBER="1-xyz" make deb"
   ```  

2. **Large Docker Image Size**  
   The generated Docker images are very large and need optimization.  
