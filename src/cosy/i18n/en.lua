return {
  ["server:listening"] =
    "server is listening on %{host}:%{port}",

  ["tos"] =
[[
Cas n°1: Utilisation du logiciel Cosyverif par téléchargement

If you download the Cosyverif software, you acknowledge that this software is distributed under the MIT license and that you accept its terms.
If you decline the terms of this license you must not download this software.

Cas n°2: Utilisation du logiciel Cosyverif directement sur le site

If you use the Cosyverif software, you acknowledge that this software is distributed under the MIT license and you accept its terms.
If you decline the terms of this license you must not use this software.

CAS 3:
- Pour le cas que quelqu'un souhaite contribuer avec des modules, c'est moins facile. 
 est-ce que celui qui propose le module vous donne une licence ?  et si oui, avec quels droits ?

Cas 3a: A l'intention du contributeur qui veut ajouter une contribution au logiciel Cosyverif

If you want that your contribution be integrated into the Cosyverif software be sure to read and accept the following provisions:

By integrating your contribution into the Cosyverif software, you warrant that you are the author of the contribution and that the latter does not infringe the intellectual property rights of a third party.

You assign your patrimonial rights to X for the duration of the patrimonial rights, for all territories throughout the world in order to distribute your contribution as a module of the Cosyverif software.
It is specified that the rights assigned to X are as follows:
- the right to reproduce the contribution in a whole,........
- the right to represent your contribution in a whole,.....
- the right to distribute your contribution under the MIT License
- the right to integrate your contribution into the Cosyverif software

This assignment of rights is granted for free.

Cas 3b: A l'intention des utilisateurs quand la contribution est intégrée au logiciel Cosyverif sans avoir été préalablement accepté par les administrateurs réseaux

Be aware the Cosyverif software contains several modules provided "as is", we do not warrant that the modules do not infringe the intellectual property rigths of a third party.
]],

  ["fixme"] =
    "FIXME: %{message}",

  ["locale:available"] =
    "i18n locale '%{loaded}' has been loaded",
  ["locale:missing"] =
    "i18n locale '%{loaded}' has not been loaded",

  ["directory:not-directory"] =
    "a %{mode} already exists at %{directory}",
  ["directory:created"] =
    "directory %{directory} has been successfully created",
  ["directory:not-created"] =
    "directory %{directory} has not been created because %{reason}",

  ["github:push"] =
    "received notification of a push in GitHub repository",

  ["dependency:success"] =
    "dependency %{source} has been downloaded and installed as %{target}",
  ["dependency:failure"] =
    "dependency %{source} is unavailable and cannot be installed as %{target}",

  ["bcrypt:rounds"] = {
    one   = "using one round in bcrypt for at least %{time} milliseconds of computation",
    other = "using %{count} rounds in bcrypt for at least %{time} milliseconds of computation",
  },

  ["token:no-secret"] =
    "token secret is not defined in configuration",

  ["smtp:not-available"] =
    "no SMTP server discovered, sending of emails will not work",
  ["smtp:available"] =
    "SMTP on %{host}:%{port} uses %{method} (encrypted with %{protocol})",
  ["smtp:discover"] =
    "discovering SMTP on %{host}:%{port} using %{method} (encrypted with %{protocol})",

  ["configuration:using"] =
    "using configuration in directory %{path}",
  ["configuration:skipping"] =
    "skipping configuration in directory %{path}, because file is missing or not readable",

  ["check:error"] =
    "some parameters are invalid or missing",

  ["check:no-check"] =
    "request argument %{key} has not been checked",
  ["check:missing"] =
    "parameter %{key} is missing",
  ["check:is-string"] =
    "a %{key} must be a string",
  ["check:min-size"] = {
    one   = "a %{key} must contain at least one character",
    other = "a %{key} must be at least %{count} characters long",
  },
  ["check:max-size"] = {
    one   = "a %{key} must contain at most one character",
    other = "a %{key} must be at most %{count} characters long",
  },

  ["check:username:alphanumeric"] =
    "a username must contain only alphanumeric characters",
  ["check:email:pattern"] =
    "an email address must comply to the standard",
  ["check:locale:pattern"] =
    "a locale must comply to the standard",
  ["check:tos_digest:pattern"] =
    "a terms of service digest must be a MD5 digest, and thus a sequence of alphanumeric characters",
  ["check:tos_digest:incorrect"] =
    "terms of service digest is does not correspond to the terms of service",
  ["check:token:invalid"] =
    "token is invalid",

  ["create-user:email-exists"] =
    "email address %{email} is already bound to an account",
  ["create-user:username-exists"] =
    "username %{username} is already a user account",

  ["authenticate:failure"] =
    "authentication failed",

  ["reset-user:retry"] =
    "reset failed, please try again later",
  ["email:reset_account:from"] =
    '"%{name}" <%{email}>',
  ["email:reset_account:to"] =
    '"%{name}" <%{email}>',
  ["email:reset_account:subject"] =
    "[%{servername}] Welcome, %{username}!",
  ["email:reset_account:body"] =
    "%{username}, your validation token is <%{validation}>.",
  
  ["token:not-validation"] =
    "token is not a validation one",
  ["token:not-authentication"] =
    "token is not an authentication one",

  ["forbidden"] =
    "action is forbidden",

  ["redis:unavailable"] =
    "redis server is unavailable",

  ["rpc:invalid"] =
    "rpc message is invalid",
  ["rpc:no-operation"] =
    "unknown operation '%{reason}'",

  ["client:timeout"] =
    "connection timed out",

  ["suspend:not-user"] =
    "account %{username} is not a user",
  ["suspend:self"] =
    "are you mad?",
  ["suspend:not-enough"] =
    "suspending a user requires %{required} reputation, but only %{owned} is owned",
}