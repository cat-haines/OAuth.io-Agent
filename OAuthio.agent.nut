const OAUTHIO_KEY = ""
BASE_URL <- http.agenturl();

oauth <- {};

function GetCredentials() {
    local data = server.load();
    if ("oauth" in data) {
        oauth = data.oauth;
        return;
    }
    
    oauth <- { token = null, token_secret = null }
    data.oauth <- oauth;
    server.load(data);
}

GetCredentials();

function LoggedIn() {
    return ("token" in oauth && oauth.token != null &&
            "token_secret" in oauth && oauth.token_secret != null);
}

function Login(token, tokenSecret) {
    if (token == null || tokenSecret == null) return false;
    
    oauth.token = token;
    oauth.token_secret = tokenSecret;
    return true;
}

function Logout() {
    oauth.token = null;
    oauth.token_secret = null;
}

const pageLayout = @"
    <!DOCTYPE html>
    <html lang='en'>
        <head>%s</head>
        <body>%s</body>
    </html>
";

const defaultPageTitle = "Electric Imp";
const defaultHead = @"
    <meta charset='utf-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1, maximum-scale=1, user-scalable=0'>
    <meta name='apple-mobile-web-app-capable' content='yes'>        
        
    <title>%s</title>

    <link href='https://d2c5utp5fpfikz.cloudfront.net/2_3_1/css/bootstrap.min.css' rel='stylesheet'>
    <link href='https://d2c5utp5fpfikz.cloudfront.net/2_3_1/css/bootstrap-responsive.min.css' rel='stylesheet'>
    <style>.centered { text-align:center; padding:40px; }</style>
    
    <!-- jQuery -->
    <script src='https://code.jquery.com/jquery-1.9.1.min.js'></script>
    <script src='https://code.jquery.com/jquery-migrate-1.2.1.min.js'></script>
    <!-- bootstrap -->
    <script src='https://d2c5utp5fpfikz.cloudfront.net/2_3_1/js/bootstrap.min.js'></script>
    <!-- Oauth.io -->
    <script src='https://devious-dorris.gopagoda.com/assets/js/oauth.min.js'></script>
    <script>
        OAuth.initialize('%s');
    </script>
    <script>
        function logSuccess(title, message) {
            var t = new Date().getTime();
            $('.container').prepend('<div id=\'' + t + '\' class=\'alert alert-success\'><button type=\'button\' class=\'close\' data-dismiss=\'alert\'>x</button><strong>' + title + '</strong>&nbsp;' + message + '</div>');
            window.setTimeout(function() { $('#' + t).alert('close'); }, 3000);
        }
    
        function logError(title, message) {
            var t = new Date().getTime();
            $('.container').prepend('<div id =\'' + t + '\'class=\'alert alert-error\'><button type=\'button\' class=\'close\' data-dismiss=\'alert\'>x</button><strong>' + title + '</strong>&nbsp;' + message + '</div>');
            window.setTimeout(function() { $('#' + t).alert('close'); }, 3000);
        }
    </script>
";

const index = @"
    <div class='container'>
        <div class='centered'>
            <h1 class='text-center'>OAuth.IO Example Agent</h1>
            <div class='well'>
                Success! You are logged in
            </div>
        </div>
    </div>
";

const login = @"
    <div class='container'>
        <div class='centered'>
            <h1 class='text-center'>Tiny Printer</h1>
            <button onclick='login()' type='button' class='btn btn-primary btn-lg'>Sign in with Twitter</button>
        </div>
    </div>

    <!-- oauth.io -->
    <script>
        function login() {
            OAuth.popup('twitter', function(err, result) {
                if(err) {
                    logError('OAuth Error', 'Could not authenticate');
                    return;
                }
                $.ajax({
                    url: 'https://agent.electricimp.com/6o5VeeJwCDpG/auth',
                    data: { token: result.oauth_token, token_secret: result.oauth_token_secret },
                    method: 'POST',
                    success: function(response) {
                        $('body').html(response);
                    },
                    error: function (request, status, error) {
                        logError('Error: Something went wrong.', '');
                    }
                });
            });
        }
    </script>
";

function defaultPageRenderingEngine(p) {
    return p;
}

function defulatHeadRenderingEngine(h) {
    return format(h, defaultPageTitle, OAUTHIO_KEY);
}

function RenderPage(page, renderPage = defaultPageRenderingEngine, head = defaultHead, renderHead = defulatHeadRenderingEngine) {
    return format(pageLayout, renderHead(head), renderPage(page));
}


function logTable(t, i = 0) {
    local indentString = "";
    for(local x = 0; x < i; x++) indentString += ".";
    
    foreach(k, v in t) {
        if (typeof(v) == "table" || typeof(v) == "array") {
            local par = "[]";
            if (typeof(v) == "table") par = "{}";
            
            server.log(indentString + k + ": " + par[0].tochar());
            logTable(v, i+4);
            server.log(par[1].tochar());
        } 
        else { 
            server.log(indentString + k + ": " + v);
        }
    }
}


http.onrequest(function(req,resp){
    try {
        server.log("got a request");
        
        local path = req.path;
        server.log(path);
        
        switch (path) {
            case "/logout": case "/logout/":
                Logout();
                // fall through to login page
            case "": case "/":
                if(LoggedIn()) {
                    resp.send(200, RenderPage(index));
                    return;
                }
            // if user isn't logged in, fall through to login page
           case "/login": case "/login/":
                resp.send(200, RenderPage(login, function(p) { return format(p, BASE_URL) }));
                return;
           case "/auth": case "/auth/":
                local authData = http.urldecode(req.body);
                foreach(k,v in authData) server.log(k + ": " + v);
                if ("token" in authData && "token_secret" in authData) {
                    if(Login(authData.token, authData.token_secret)) {
                        server.log("logged in");
                        resp.send(200, index);
                        return;
                    }
                }
                resp.send(403, "Bad Credentials");
                return;
        }
        
        resp.send(404, "Unknown");
    } catch (ex) {
        resp.send(500, "Internal Server Error: " + ex);
    }
});
