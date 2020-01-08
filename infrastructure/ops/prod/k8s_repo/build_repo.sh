mkdir -p tmp
gsutil cp gs://${tfadmin_proj?env not set}/ops/k8s/cloudbuild.yaml tmp/cloudbuild.yaml
mkdir -p tmp/${ops_gke_1_name?env not set}/istio-controlplane
mkdir -p tmp/${ops_gke_2_name?env not set}/istio-controlplane
mkdir -p tmp/${ops_gke_3_name?env not set}/istio-controlplane
mkdir -p tmp/${dev1_gke_1_name?env not set}/istio-controlplane
mkdir -p tmp/${dev1_gke_2_name?env not set}/istio-controlplane
mkdir -p tmp/${dev2_gke_3_name?env not set}/istio-controlplane
mkdir -p tmp/${dev2_gke_4_name?env not set}/istio-controlplane
mkdir -p tmp/${dev3_gke_5_name?env not set}/istio-controlplane
mkdir -p tmp/${dev3_gke_6_name?env not set}/istio-controlplane

# Copy core resources to every cluster
echo $(ls -d tmp/*/istio-controlplane) | xargs -n 1 cp config/istio-controlplane/istio-system-namespace.yaml
echo $(ls -d tmp/*/istio-controlplane) | xargs -n 1 cp config/istio-controlplane/istio-system-psp.yaml
echo $(ls -d tmp/*/istio-controlplane) | xargs -n 1 cp config/istio-controlplane/istio-system-rbac.yaml
echo $(ls -d tmp/*/istio-controlplane) | xargs -n 1 cp config/istio-controlplane/kustomization.yaml
echo $(ls -d tmp/*/) | xargs -n 1 cp config/kustomization.yaml

# Copy script used to setup multi-cluster service discovery
cp config/make_multi_cluster_config.sh tmp/

# Copy downloaded istio operator to every cluster
gsutil -m cp -r gs://${tfadmin_proj}/ops/istio-operator-${istio_version?env not set} .
mv istio-operator-${istio_version} istio-operator
echo $(ls -d tmp/*/) | xargs -n 1 cp -r istio-operator
rm -Rf istio-operator*
echo $(ls -d tmp/*/) | xargs -n 1 cp config/istio-operator-psp.yaml
echo $(ls -d tmp/*/) | xargs -n 1 cp config/jsonpatch-istio-operator-clusterrole.yaml

# Copy downloaded cnrm controller to every cluster and replace project ID.
echo $(ls -d tmp/*/) | xargs -n 1 cp -r config/cnrm-system/
gsutil -m cp -r gs://${tfadmin_proj}/ops/cnrm/install-bundle .
echo $(ls -d tmp/*/cnrm-system) | xargs -n 1 cp -r install-bundle
rm -Rf install-bundle

# Replace project ID in cnrm resources
sed -i 's/${PROJECT_ID?}/'${ops_project_id?}'/g' tmp/${ops_gke_1_name}/cnrm-system/{install-bundle/0-cnrm-system.yaml,patch-cnrm-system-namespace.yaml}
sed -i 's/${PROJECT_ID?}/'${ops_project_id?}'/g' tmp/${ops_gke_2_name}/cnrm-system/{install-bundle/0-cnrm-system.yaml,patch-cnrm-system-namespace.yaml}
sed -i 's/${PROJECT_ID?}/'${ops_project_id?}'/g' tmp/${ops_gke_3_name}/cnrm-system/{install-bundle/0-cnrm-system.yaml,patch-cnrm-system-namespace.yaml}
sed -i 's/${PROJECT_ID?}/'${dev1_project_id?}'/g' tmp/${dev1_gke_1_name}/cnrm-system/{install-bundle/0-cnrm-system.yaml,patch-cnrm-system-namespace.yaml}
sed -i 's/${PROJECT_ID?}/'${dev1_project_id?}'/g' tmp/${dev1_gke_2_name}/cnrm-system/{install-bundle/0-cnrm-system.yaml,patch-cnrm-system-namespace.yaml}
sed -i 's/${PROJECT_ID?}/'${dev2_project_id?}'/g' tmp/${dev2_gke_3_name}/cnrm-system/{install-bundle/0-cnrm-system.yaml,patch-cnrm-system-namespace.yaml}
sed -i 's/${PROJECT_ID?}/'${dev2_project_id?}'/g' tmp/${dev2_gke_4_name}/cnrm-system/{install-bundle/0-cnrm-system.yaml,patch-cnrm-system-namespace.yaml}
sed -i 's/${PROJECT_ID?}/'${dev3_project_id?}'/g' tmp/${dev3_gke_5_name}/cnrm-system/{install-bundle/0-cnrm-system.yaml,patch-cnrm-system-namespace.yaml}
sed -i 's/${PROJECT_ID?}/'${dev3_project_id?}'/g' tmp/${dev3_gke_6_name}/cnrm-system/{install-bundle/0-cnrm-system.yaml,patch-cnrm-system-namespace.yaml}

# Copy generated CA certs to every cluster.
gsutil cp -r gs://${tfadmin_proj}/ops/istiocerts .
kubectl create secret generic -n istio-system \
--from-file=istiocerts/ca-cert.pem \
--from-file=istiocerts/ca-key.pem \
--from-file=istiocerts/root-cert.pem \
--from-file=istiocerts/cert-chain.pem \
--dry-run cacerts -oyaml > istio-cacerts.yaml
echo $(ls -d tmp/*/istio-controlplane/) | xargs -n 1 cp istio-cacerts.yaml
rm -Rf istiocerts*

cat - | tee tmp/README.md << EOF
This is where the k8s manifests live.
EOF

# Add cacerts to all controlplane kustomizations
for d in $(ls -d tmp/*/istio-controlplane); do
  (cd $d && kustomize edit add resource istio-cacerts.yaml)
done

# Patch ops 1 cluster istio controlplane CR with static ILB IPs
SRC="config/istio-controlplane/istio-replicated-controlplane.yaml"
DEST="tmp/${ops_gke_1_name}/istio-controlplane/$(basename $SRC)"
sed \
  -e "s/POLICY_ILB_IP/${ops_gke_1_policy_ilb?env not set}/g" \
  -e "s/TELEMETRY_ILB_IP/${ops_gke_1_telemetry_ilb?env not set}/g" \
  -e "s/PILOT_ILB_IP/${ops_gke_1_pilot_ilb?env not set}/g" \
  $SRC > $DEST

# Update kustomization
(cd $(dirname $DEST) && kustomize edit add resource $(basename $DEST))

# Patch ops 2 cluster istio controlplane CR with static ILB IPs
SRC="config/istio-controlplane/istio-replicated-controlplane.yaml"
DEST="tmp/${ops_gke_2_name}/istio-controlplane/$(basename $SRC)"
sed \
  -e "s/POLICY_ILB_IP/${ops_gke_2_policy_ilb?env not set}/g" \
  -e "s/TELEMETRY_ILB_IP/${ops_gke_2_telemetry_ilb?env not set}/g" \
  -e "s/PILOT_ILB_IP/${ops_gke_2_pilot_ilb?env not set}/g" \
  $SRC > $DEST

# Update kustomization
(cd $(dirname $DEST) && kustomize edit add resource $(basename $DEST))

# Patch ops 3 cluster istio controlplane CR with static ILB IPs
SRC="config/istio-controlplane/istio-replicated-controlplane.yaml"
DEST="tmp/${ops_gke_3_name}/istio-controlplane/$(basename $SRC)"
sed \
    -e "s/POLICY_ILB_IP/${ops_gke_3_policy_ilb?env not set}/g" \
    -e "s/TELEMETRY_ILB_IP/${ops_gke_3_telemetry_ilb?env not set}/g" \
    -e "s/PILOT_ILB_IP/${ops_gke_3_pilot_ilb?env not set}/g" \
    $SRC > $DEST

# Update kustomization
(cd $(dirname $DEST) && kustomize edit add resource $(basename $DEST))

# Patch dev 1 clusters 1 and 2 with ILB IPs from ops 1.
for cluster in ${dev1_gke_1_name} ${dev1_gke_2_name}; do
  SRC="config/istio-controlplane/istio-shared-controlplane.yaml"
  DEST="tmp/$cluster/istio-controlplane/$(basename $SRC)"
  sed \
    -e "s/POLICY_ILB_IP/${ops_gke_1_policy_ilb}/g" \
    -e "s/TELEMETRY_ILB_IP/${ops_gke_1_telemetry_ilb}/g" \
    -e "s/PILOT_ILB_IP/${ops_gke_1_pilot_ilb}/g" \
    $SRC > $DEST
  
  # Update kustomization
  (cd $(dirname $DEST) && kustomize edit add resource $(basename $DEST))
done

# Patch dev 2 clusters 3 and 4 with ILB IPs from ops 2.
for cluster in ${dev2_gke_3_name} ${dev2_gke_4_name}; do
  SRC="config/istio-controlplane/istio-shared-controlplane.yaml"
  DEST="tmp/$cluster/istio-controlplane/$(basename $SRC)"
  sed \
    -e "s/POLICY_ILB_IP/${ops_gke_2_policy_ilb}/g" \
    -e "s/TELEMETRY_ILB_IP/${ops_gke_2_telemetry_ilb}/g" \
    -e "s/PILOT_ILB_IP/${ops_gke_2_pilot_ilb}/g" \
    $SRC > $DEST
  # Update kustomization
  (cd $(dirname $DEST) && kustomize edit add resource $(basename $DEST))
done

# Patch dev 3 clusters 5 and 5 with ILB IPs from ops 3.
for cluster in ${dev3_gke_5_name} ${dev3_gke_6_name}; do
  SRC="config/istio-controlplane/istio-shared-controlplane.yaml"
  DEST="tmp/$cluster/istio-controlplane/$(basename $SRC)"
  sed \
    -e "s/POLICY_ILB_IP/${ops_gke_3_policy_ilb}/g" \
    -e "s/TELEMETRY_ILB_IP/${ops_gke_3_telemetry_ilb}/g" \
    -e "s/PILOT_ILB_IP/${ops_gke_3_pilot_ilb}/g" \
    $SRC > $DEST
  # Update kustomization
  (cd $(dirname $DEST) && kustomize edit add resource $(basename $DEST))
done
    

# Clone the git ops repo to the workspace
rm -rf ${k8s_repo_name}
git config --global user.email $(gcloud auth list --filter=status:ACTIVE --format='value(account)')
git config --global user.name "terraform"
git config --global credential.'https://source.developers.google.com'.helper gcloud.sh
gcloud source repos clone ${k8s_repo_name} --project=${ops_project_id}

# Copy repo files, overwrite existing files.
cp -r tmp/. ${k8s_repo_name}

# Copy multi-cluster service disscovery kubeconfig template if it doesn't already exist
if [[ ! -d ${k8s_repo_name}/.kubeconfigs ]]; then
  cp -r config/kubeconfigs ${k8s_repo_name}/.kubeconfigs
fi

# Copy app template if it doesn't already exist.
for d in $(ls -d ${k8s_repo_name}/*/); do
  [[ ! -d "${d}/app" ]] && cp -r config/app ${d}/
done

# Copy app-ingress template if it doesn't already exist.
for d in $(ls -d ${k8s_repo_name}/*/); do
  [[ ! -d "${d}/app-ingress" ]] && cp -r config/app-ingress ${d}/
done

# Copy app-cnrm template if it doesn't already exist.
for d in $(ls -d ${k8s_repo_name}/*/); do
  [[ ! -d "${d}/app-cnrm" ]] && cp -r config/app-cnrm ${d}/
done

# Push changes to the repo
cd ${k8s_repo_name}
git diff
git add . && git commit -am "cloudbuild"
git push -u origin master