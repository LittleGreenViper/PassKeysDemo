DROP TABLE IF EXISTS webauthn_credentials;
CREATE TABLE webauthn_credentials (
  userId varchar(255) UNIQUE NOT NULL,
  credentialId varchar(255) UNIQUE NOT NULL,
  displayName varchar(255) NOT NULL,
  signCount int NOT NULL DEFAULT 0,
  bearerToken varchar(255) DEFAULT NULL,
  publicKey text
);
DROP TABLE IF EXISTS passkeys_demo_users;
CREATE TABLE passkeys_demo_users (
  userId varchar(255) UNIQUE NOT NULL,
  displayName varchar(255) NOT NULL,
  credo varchar(255) NOT NULL
);
