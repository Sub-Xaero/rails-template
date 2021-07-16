export function isHTMLFormElement(element: Element): element is HTMLFormElement {
  return element instanceof HTMLFormElement;
}

export function isHTMLElement(element: Element): element is HTMLElement {
  return element instanceof HTMLElement;
}

export function isHTMLSelectElement(element: Element): element is HTMLSelectElement {
  return element instanceof HTMLSelectElement;
}

export function isHTMLTextAreaElement(element: Element): element is HTMLTextAreaElement {
  return element instanceof HTMLTextAreaElement;
}

export function isHTMLInputElement(element: Element): element is HTMLInputElement {
  return element instanceof HTMLInputElement;
}

export function elementCanBeDisabled(element: HTMLElement): element is HTMLElement & { disabled: boolean } {
  return (element instanceof HTMLInputElement || element instanceof HTMLSelectElement || element instanceof HTMLTextAreaElement);
}