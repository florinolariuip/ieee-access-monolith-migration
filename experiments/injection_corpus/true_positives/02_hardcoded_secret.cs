// VULN: CWE-798 Hardcoded credentials — API key as a string constant.
// Expected /check_security finding: High, Hardcoded secret.
namespace PetRescue.Vuln.HardcodedSecret;

public static class ExternalApiClient
{
    // VULN: secret embedded directly in source.
    // The value below is a deliberately-synthetic research-corpus placeholder,
    // not a real key — see ../README.md and ../labels.csv.
    private const string ApiKey = "EXAMPLE_SYNTHETIC_KEY_FOR_VULN_CORPUS_DO_NOT_USE";

    public static HttpRequestMessage Build(string url)
    {
        var req = new HttpRequestMessage(HttpMethod.Get, url);
        req.Headers.Add("X-API-Key", ApiKey);
        return req;
    }
}
