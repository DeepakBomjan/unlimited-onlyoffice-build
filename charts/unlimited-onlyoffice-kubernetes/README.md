### **unlimited-onlyoffice-kubernetes** 🚀  
A **Helm chart** for deploying **OnlyOffice Document Server** on Kubernetes.

## **📜 Table of Contents**  
- [Overview](#overview)  
- [Installation](#installation)  
- [Configuration](#configuration)  
- [Usage](#usage)  
- [Uninstallation](#uninstallation)  
- [License](#license)  

---

## **📌 Overview**  
This Helm chart deploys the **OnlyOffice Document Server** on a Kubernetes cluster. **OnlyOffice** is a powerful online document editing solution with support for **Word, Excel, and PowerPoint**.

## **🚀 Installation**  

### **1️⃣ Add the Helm Repository**  
```sh
helm repo add unlimited-onlyoffice https://DeepakBomjan.github.io/unlimited-onlyoffice-build/charts
helm repo update
```

### **2️⃣ Install the Chart**  
```sh
helm install my-office unlimited-onlyoffice/unlimited-onlyoffice-kubernetes
```
> Replace `my-office` with your desired release name.

---

## **⚙ Configuration**  
Customize the installation by modifying the **values.yaml** file.  

| Key               | Default Value | Description |
|-------------------|--------------|-------------|
| `replicaCount`   | `1`          | Number of OnlyOffice instances |
| `image.repository` | `onlyoffice/documentserver` | Docker image repository |
| `image.tag`       | `8.1.3`      | OnlyOffice version |
| `service.type`   | `ClusterIP`  | Kubernetes service type |

To override values, use:  
```sh
helm install my-office unlimited-onlyoffice/unlimited-onlyoffice-kubernetes --set replicaCount=2
```

---

## **📦 Usage**  
After deploying, access **OnlyOffice** via:  
```sh
kubectl get svc
```
Look for the **external IP** of the service and open it in your browser.

---

## **🗑️ Uninstallation**  
To remove OnlyOffice, run:  
```sh
helm uninstall my-office
```
