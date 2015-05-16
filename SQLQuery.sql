-- Cr�ation de la base de donn�es
create database CampingParadis;
go

use CampingParadis;
go

-- cr�ation des donn�es du magasin
create schema Magasin;
go

create table Magasin.Magasin (
  ID int identity(1,1) primary key,
  Nom varchar(64) not null unique,
  Telephone varchar(32)
)

create table Magasin.Stock(
  IDMagasin int not null,
  IDProduit int not null,
  Quantite int not null,
  primary key (IDMagasin, IDProduit)
)

create table Magasin.Produit(
  ID int identity(1,1) primary key,
  Marque varchar(64) not null,
  PrixUnitaire money not null,
  Contenance decimal(8,2) not null,
  Unite varchar(16) not null,
  IDGamme int not null
)

create table Magasin.Gamme (
  ID int identity(1,1) primary key,
  Libelle varchar(64) not null unique,
  IDFamille int not null,
);

create table Magasin.Famille (
  ID int identity(1,1) primary key,
  Libelle varchar(64) not null unique,
);

create table Magasin.FamilleHerarchie (
  IDFamille int,
  IDParent int,
  primary key (IDFamille, IDParent)
)

insert into Magasin.Magasin (Nom)
values ('La superette des Bellettes grises');

insert into Magasin.Famille (Libelle)
values ('L�gumes');
insert into Magasin.Famille (Libelle)
values ('Conserves');
insert into Magasin.Famille (Libelle)
values ('L�gumes frais');
insert into Magasin.Famille (Libelle)
values ('L�gumes surgel�s');
insert into Magasin.Famille (Libelle)
values ('Conserves de l�gumes');

insert into Magasin.FamilleHerarchie (IDFamille,IDParent)
values((select ID from Magasin.Famille where Libelle = 'L�gumes frais'),
       (select ID from Magasin.Famille where Libelle = 'L�gumes'));
insert into Magasin.FamilleHerarchie (IDFamille,IDParent)
values((select ID from Magasin.Famille where Libelle = 'L�gumes surgel�s'),
       (select ID from Magasin.Famille where Libelle = 'L�gumes'));
insert into Magasin.FamilleHerarchie (IDFamille,IDParent)
values((select ID from Magasin.Famille where Libelle = 'Conserves de l�gumes'),
       (select ID from Magasin.Famille where Libelle = 'L�gumes'));
insert into Magasin.FamilleHerarchie (IDFamille,IDParent)
values((select ID from Magasin.Famille where Libelle = 'Conserves de l�gumes'),
       (select ID from Magasin.Famille where Libelle = 'Conserves'));

insert into Magasin.Gamme(Libelle, IDFamille)
values('Petits pois en conserve',
       (select ID from Magasin.Famille where Libelle = 'Conserves de l�gumes'));

insert into Magasin.Produit(Marque, PrixUnitaire, Contenance, Unite, IDGamme)
values('Marie',1.25,800,'gr',(select ID from Magasin.Gamme where Libelle = 'Petits pois en conserve'));
insert into Magasin.Produit(Marque, PrixUnitaire, Contenance, Unite, IDGamme)
values('Marie',0.75,400,'gr',(select ID from Magasin.Gamme where Libelle = 'Petits pois en conserve'));
insert into Magasin.Produit(Marque, PrixUnitaire, Contenance, Unite, IDGamme)
values('Ren�',0.49,800,'gr',(select ID from Magasin.Gamme where Libelle = 'Petits pois en conserve'));

insert into Magasin.Stock (IDMagasin, IDProduit, Quantite)
values((select ID from Magasin.Magasin where Nom = 'La superette des Bellettes grises'),
       1,
       25);
insert into Magasin.Stock (IDMagasin, IDProduit, Quantite)
values((select ID from Magasin.Magasin where Nom = 'La superette des Bellettes grises'),
       2,
       12);
insert into Magasin.Stock (IDMagasin, IDProduit, Quantite)
values((select ID from Magasin.Magasin where Nom = 'La superette des Bellettes grises'),
       3,
       5);

alter table Magasin.FamilleHerarchie
add constraint fk_famillehierarchie_familleid
foreign key (IDFamille) references Magasin.Famille (ID);

alter table Magasin.FamilleHerarchie
add constraint fk_famillehierarchie_familleparent
foreign key (IDParent) references Magasin.Famille (ID);

alter table Magasin.Gamme
add constraint fk_gamme_famille
foreign key (IDFamille) references Magasin.Famille (ID);

alter table Magasin.Produit
add constraint fk_produit_gamme
foreign key (IDGamme) references Magasin.Gamme (ID);

alter table Magasin.Stock
add constraint fk_stock_produit
foreign key (IDProduit) references Magasin.Produit (ID);

alter table Magasin.Stock
add constraint fk_stock_magasin
foreign key (IDMagasin) references Magasin.Magasin (ID);
go

create view Magasin.FamilleDetails(ID, Libelle, Parent)
as
    select F.ID, F.Libelle, P.Libelle Parent
    from Magasin.Famille F,Magasin.FamilleHerarchie H, Magasin.Famille P
    where F.ID = H.IDFamille
      and H.IDParent = P.ID
  union
    select *, null Parent
    from Magasin.Famille F
    where ID not in (select distinct IDFamille from Magasin.FamilleHerarchie);
go