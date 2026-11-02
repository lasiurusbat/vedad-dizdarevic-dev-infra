// Placeholder so Terraform can create the function. Real code lives in the app repo
// (lambda/contact) and replaces this; Terraform ignores code changes (see lambda.tf).
export const handler = async () => ({
  statusCode: 503,
  headers: { "content-type": "application/json" },
  body: JSON.stringify({ error: "not deployed" }),
});
