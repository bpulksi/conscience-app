// Generates flutter/lib/firebase_options.dart from google-services.json at build
// time, so the app's settings always match the GOOGLE_SERVICES_JSON secret and
// no project keys are committed to this public repository.
//
// Usage: node write-firebase-options.js <google-services.json> <output.dart>
const fs = require("fs");

const PACKAGE = "com.conscience.app";
const [input, output] = process.argv.slice(2);

function fail(message) {
  console.log(`::error title=Firebase settings::${message}`);
  process.exit(1);
}

let config;
try {
  config = JSON.parse(fs.readFileSync(input, "utf8"));
} catch {
  fail("google-services.json is not valid JSON. Check the GOOGLE_SERVICES_JSON secret.");
}

const client = (config.client ?? []).find(
  (c) => c.client_info?.android_client_info?.package_name === PACKAGE
);
if (!client) fail(`GOOGLE_SERVICES_JSON has no app registered as ${PACKAGE}.`);

const values = {
  apiKey: client.api_key?.[0]?.current_key,
  appId: client.client_info?.mobilesdk_app_id,
  messagingSenderId: config.project_info?.project_number,
  projectId: config.project_info?.project_id,
  storageBucket: config.project_info?.storage_bucket,
};
for (const [name, value] of Object.entries(values)) {
  if (name !== "storageBucket" && !value) fail(`GOOGLE_SERVICES_JSON is missing ${name}.`);
}

const fields = Object.entries(values)
  .filter(([, value]) => value)
  .map(([name, value]) => `    ${name}: ${JSON.stringify(value).replace(/\$/g, "\\$")},`)
  .join("\n");

fs.writeFileSync(
  output,
  `// Generated at build time by .github/scripts/write-firebase-options.js.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static const FirebaseOptions currentPlatform = FirebaseOptions(
${fields.replace(/^/gm, "  ")}
  );
}
`
);
console.log(`Firebase settings written for project ${values.projectId}`);
