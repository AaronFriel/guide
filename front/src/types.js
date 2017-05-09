// @flow

export type Category = {
  uid   : string,
  link  : string,
  title : string
};

export type GrandCategoryT = {
  title    : string,
  finished : Array<Category>,
  wip      : Array<Category>,
  stubs    : Array<Category>
};

export type Description = {
  text : string, 
  html : string
};

export type Valoration = {
  uid : string,
  content : Description,
};

export type Kind = {
  tag : string,
  hackageName : string
};

export type Note = {
  text : string
};

export type Item = {
  ecosystem : Description,
  group_ : string,
  kind : Kind,
  created : string,
  link : string,
  uid : string,
  consDeleted : Array<String>,
  name : string,
  prosDeleted : Array<String>,
  notes : Note,
  description: Description,
  pros : Array<Valoration>,
  cons : Array<Valoration>
};

export type Cat = {
  uid: string,
  title : string,
  group: string,
  description : Description,
  items : Array<Item>
};