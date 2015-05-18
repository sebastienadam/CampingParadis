-- Création de la base de données
create database CampingParadis;
go

use CampingParadis;
go

-- création des données du magasin
create schema Magasin;
go

-- TODO:
-- * procédure 'vendre produit'
-- * procédure 'approvisionnement stock'
-- * procédure 'nouveau produit'
-- * procédure 'nouvelle gamme'
-- * procédure 'nouvelle famille' => paramètre 'parent' optionnel
-- * procédure 'nouvelle hiérarchie famille'

create table Magasin.Magasin (
  ID int identity(1,1) primary key,
  Nom varchar(64) not null unique,
  Telephone varchar(32)
);

create table Magasin.Stock(
  IDMagasin int not null,
  IDProduit int not null,
  Quantite int not null,
  Epuise tinyint not null default 0,
  primary key (IDMagasin, IDProduit)
);

create table Magasin.HistoriqueVente (
  ID int identity(1,1) primary key,
  IDProduit int,
  Prix money,
  Quantite int,
  DateVente DateTime,
  Vendeur varchar(65)
);

create table Magasin.Produit(
  ID int identity(1,1) primary key,
  Marque varchar(64) not null,
  PrixUnitaire money not null,
  Contenance decimal(8,2) not null,
  Unite varchar(16) not null,
  IDGamme int not null
);

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
);
go

create trigger Magasin.trigger_stock_epuise
on Magasin.Stock
after insert, update
as
begin
  if update(Quantite) begin
    declare @IDMag int;
    declare @IDProd int;
    declare @Quantite int;
    declare @Epuise int;
    select @IDMag = IDMagasin, @IDProd = IDProduit, @Quantite = Quantite
    from inserted;
    if(@Quantite = 0) begin
      set @Epuise = 0;
    end else if(@Quantite < 5) begin
      set @Epuise = 1;
    end else begin
      set @Epuise = 2;
    end
    update Magasin.Stock
    set Epuise = @Epuise
    where IDMagasin = @IDMag and IDProduit = @IDProd;
  end
end
go

create trigger Magasin.trigger_historique_vente_non_modifiable
on Magasin.HistoriqueVente
after update, delete
as begin
  rollback
end
go

-- remplissage des tables du magasin
insert into Magasin.Magasin (Nom)
values ('La superette des Bellettes grises');

insert into Magasin.Famille (Libelle)
values ('Légumes');
insert into Magasin.Famille (Libelle)
values ('Conserves');
insert into Magasin.Famille (Libelle)
values ('Légumes frais');
insert into Magasin.Famille (Libelle)
values ('Légumes surgelés');
insert into Magasin.Famille (Libelle)
values ('Conserves de légumes');

insert into Magasin.FamilleHerarchie (IDFamille,IDParent)
values((select ID from Magasin.Famille where Libelle = 'Légumes frais'),
       (select ID from Magasin.Famille where Libelle = 'Légumes'));
insert into Magasin.FamilleHerarchie (IDFamille,IDParent)
values((select ID from Magasin.Famille where Libelle = 'Légumes surgelés'),
       (select ID from Magasin.Famille where Libelle = 'Légumes'));
insert into Magasin.FamilleHerarchie (IDFamille,IDParent)
values((select ID from Magasin.Famille where Libelle = 'Conserves de légumes'),
       (select ID from Magasin.Famille where Libelle = 'Légumes'));
insert into Magasin.FamilleHerarchie (IDFamille,IDParent)
values((select ID from Magasin.Famille where Libelle = 'Conserves de légumes'),
       (select ID from Magasin.Famille where Libelle = 'Conserves'));

insert into Magasin.Gamme(Libelle, IDFamille)
values('Petits pois en conserve',
       (select ID from Magasin.Famille where Libelle = 'Conserves de légumes'));

insert into Magasin.Produit(Marque, PrixUnitaire, Contenance, Unite, IDGamme)
values('Marie',1.25,800,'gr',(select ID from Magasin.Gamme where Libelle = 'Petits pois en conserve'));
insert into Magasin.Produit(Marque, PrixUnitaire, Contenance, Unite, IDGamme)
values('Marie',0.75,400,'gr',(select ID from Magasin.Gamme where Libelle = 'Petits pois en conserve'));
insert into Magasin.Produit(Marque, PrixUnitaire, Contenance, Unite, IDGamme)
values('René',0.49,800,'gr',(select ID from Magasin.Gamme where Libelle = 'Petits pois en conserve'));

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

-- ajout des contraintes sur les tables du magasin
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

alter table Magasin.HistoriqueVente
add constraint fk_historiquevente_produit
foreign key (IDProduit) references Magasin.Produit (ID);
go

-- création d'une vue pour afficher les familles avec leur parent
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