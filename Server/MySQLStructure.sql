DROP TABLE IF EXISTS `webauthn_credentials`;
CREATE TABLE `webauthn_credentials` (
  `user_id` varchar(255) NOT NULL,
  `credential_id` varbinary(255) NOT NULL,
  `public_key` text NOT NULL
);
DROP TABLE IF EXISTS `passkeys_demo_users`;
CREATE TABLE `passkeys_demo_users` (
  `id` int(11) NOT NULL,
  `user_id` varchar(255) NOT NULL,
  `user_name` varchar(255) NOT NULL,
  `user_credo` text
);
