-- Supabase Dashboard -> SQL Editor me ye poora paste karke Run karein

create table if not exists mediums (
  id bigint generated always as identity primary key,
  name text not null,
  image_url text,           -- Google Drive link ya koi bhi photo link
  sort_order int default 0
);

create table if not exists classes (
  id bigint generated always as identity primary key,
  name text not null,       -- jaise "Class 1"
  image_url text,
  sort_order int default 0
);

create table if not exists subjects (
  id bigint generated always as identity primary key,
  medium_id bigint not null references mediums(id) on delete cascade,
  class_id  bigint not null references classes(id) on delete cascade,
  name text not null,       -- jaise "Mathematics", "Grammar"
  image_url text,
  sort_order int default 0
);

create table if not exists chapters (
  id bigint generated always as identity primary key,
  subject_id bigint not null references subjects(id) on delete cascade,
  name text not null,
  image_url text,
  sort_order int default 0
);

create table if not exists contents (
  id bigint generated always as identity primary key,
  chapter_id bigint not null references chapters(id) on delete cascade,
  type text not null check (type in ('video','pdf','qa')),
  title text not null,      -- video/pdf ka naam, ya qa me sawaal
  url text,                 -- video: Bunny link, pdf: Drive/Bunny link
  body text,                -- sirf qa me: jawab
  sort_order int default 0
);

-- App sirf padh sakti hai (likhna sirf aap Dashboard se karenge)
alter table mediums  enable row level security;
alter table classes  enable row level security;
alter table subjects enable row level security;
alter table chapters enable row level security;
alter table contents enable row level security;

create policy "read mediums"  on mediums  for select using (true);
create policy "read classes"  on classes  for select using (true);
create policy "read subjects" on subjects for select using (true);
create policy "read chapters" on chapters for select using (true);
create policy "read contents" on contents for select using (true);

-- Namune ka data (baad me hata sakte hain)
insert into mediums (name, sort_order) values ('English Medium',1),('Assamese Medium',2),('Bengali Medium',3);
insert into classes (name, sort_order)
  select 'Class '||g, g from generate_series(1,12) g;
insert into subjects (medium_id, class_id, name, sort_order)
  select m.id, c.id, s.name, s.ord
  from mediums m, classes c,
       (values ('Mathematics',1),('Science',2),('Social Science',3),('English',4),('Assamese',5),('Grammar',6)) as s(name, ord)
  where m.name='English Medium' and c.name='Class 10';
