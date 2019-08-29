user "openapi" do
  action :create
  home "/home/openapi"
  create_home true
end

directory "/home/openapi/devel" do
  mode "701"
  owner "openapi"
  group "openapi"
end

execute "add crystal apt-key" do
  user "root"
  command %q{curl -sL "https://keybase.io/crystal/pgp_keys.asc" | sudo apt-key add -}
end

execute "add crystal deb" do
  user "root"
  command %q{echo "deb https://dist.crystal-lang.org/apt crystal main" | sudo tee /etc/apt/sources.list.d/crystal.list}
end

execute "apt update" do
  user "root"
  command "apt update"
end

package "crystal" do
  user "root"
  action :install
  options "--force-yes"
end

githubUser = node["github"]["username"]
githubPassword = node["github"]["password"]

git "/home/openapi/devel/OpenAPIServer" do
  user "openapi"
  repository "https://#{githubUser}:#{githubPassword}@github.com/LightningDAISY/OpenAPIServer.git"
  not_if "test -d /home/openapi/devel/OpenAPIServer"
end

execute "rm lock" do
  user "openapi"
  command "rm /home/openapi/devel/OpenAPIServer/shards.lock"
  only_if "test -d /home/openapi/devel/OpenAPIServer/shards.lock"
end

execute "shards" do
  user "openapi"
  cwd "/home/openapi/devel/OpenAPIServer"
  command "shards"
end

package "libleveldb-dev" do
  user "root"
  action :install
  options "--force-yes"
end

package "libleveldb1v5" do
  user "root"
  action :install
  options "--force-yes"
end

package "libsnappy1v5" do
  user "root"
  action :install
  options "--force-yes"
end

execute "config copy" do
  user "openapi"
  cwd "/home/openapi/devel/OpenAPIServer"
  command "cp config.toml.dist config.toml"
end

execute "build server" do
  user "openapi"
  cwd "/home/openapi/devel/OpenAPIServer"
  command "crystal build src/openapiserver.cr"
end

execute "run server" do
  user "openapi"
  cwd "/home/openapi/devel/OpenAPIServer"
  command "/home/openapi/devel/OpenAPIServer/openapiserver 1>/dev/null 2>/dev/null &"
end

