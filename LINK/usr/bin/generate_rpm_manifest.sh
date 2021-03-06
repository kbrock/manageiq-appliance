#!/bin/bash

manifest_dir=$APPLIANCE_SOURCE_DIRECTORY/../manifest
mkdir -p $manifest_dir

pushd $manifest_dir
  #
  # Generate RPM manifest
  #

  manifest=rpm_manifest_$(date +"%m%d%y").csv

  # dnf command gives yum repo used to install rpm
  dnf list --installed | tr -s " " | while read name_arch version license
  do
    if [[ "$name_arch" == "Installed" ]]; then continue; fi
    IFS=. read name arch <<< $name_arch
    echo -e "$name\t$version\t$license" >> dnf_list
  done
  sort -o dnf_list dnf_list

  # rpm command gives rpm license info
  rpm -qa --qf '%{name}\t%{version}-%{release}.%{arch}\t"%{license}"\n' |sort > rpm_list
  sed -i '/^gpg-pubkey/d' rpm_list

  echo "name,version,license,repo" > $manifest
  join -j 1 -o 1.1,1.2,1.3,2.3 -t $'\t' -a 1 rpm_list dnf_list >> $manifest
  sed -i 's/\t/,/g' $manifest
  rm -f rpm_list dnf_list

  #
  # Generate RPM repo manifest
  #
  repo_manifest=rpm_repo_manifest_$(date +"%m%d%y").csv

  dnf repolist -v enabled | ruby -r csv -e "$(cat <<- EORUBY
    CSV(STDOUT) do |csv|
      csv << %w[id name filename baseurl mirrors metalink]
      STDIN
        .grep(/^Repo-/)
        .map { |line| line.chomp.split(":", 2).map(&:strip) }
        .slice_when { |_, (k, _)| k == "Repo-id" }
        .map { |repo| repo.to_h.values_at(*%w[Repo-id Repo-name Repo-filename Repo-baseurl Repo-mirrors Repo-metalink]) }
        .sort_by { |repo| repo.first.downcase }
        .each { |repo| csv << repo }
    end
EORUBY
  )" > $repo_manifest

popd
