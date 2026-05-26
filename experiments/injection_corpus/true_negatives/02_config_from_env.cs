// CLEAN: configuration value pulled from env/config. /check_security should NOT flag.
using Microsoft.Extensions.Configuration;

namespace PetRescue.Clean.Secret;

public class ExternalApiClient
{
    private readonly string _apiKey;
    public ExternalApiClient(IConfiguration config)
    {
        _apiKey = config["ExternalApi:ApiKey"]
            ?? throw new InvalidOperationException("ExternalApi:ApiKey is not configured");
    }

    public HttpRequestMessage Build(string url)
    {
        var req = new HttpRequestMessage(HttpMethod.Get, url);
        req.Headers.Add("X-API-Key", _apiKey);
        return req;
    }
}
