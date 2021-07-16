import {Application} from "stimulus";
import {definitionsFromContext} from "stimulus/webpack-helpers";

export function loadStimulusDefinitionsFromContexts(application: Application, ...context: any[]) {
  context.forEach(context => application.load(definitionsFromContext(context)));
}