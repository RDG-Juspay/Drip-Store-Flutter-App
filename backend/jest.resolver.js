'use strict';
// Node.js < 14.18.0 does not understand the "node:" built-in prefix used by
// newer transitive dependencies. This resolver strips the prefix so Jest can
// locate the native module.
module.exports = (request, options) => {
  return options.defaultResolver(
    request.startsWith('node:') ? request.slice(5) : request,
    options
  );
};
