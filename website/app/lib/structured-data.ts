/** JSON inside a script element must not be able to close its HTML container. */
export function jsonForScript(value: object): string {
  return JSON.stringify(value).replace(/</g, "\\u003c");
}
