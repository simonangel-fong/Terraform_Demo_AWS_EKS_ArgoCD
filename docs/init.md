```sh
terraform -chdir=infra/eks init
terraform -chdir=infra/eks fmt && terraform -chdir=infra/eks validate
terraform -chdir=infra/eks apply -auto-approve
```

- Console
