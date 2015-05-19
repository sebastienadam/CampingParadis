SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- =============================================
-- Création de la base de données
-- =============================================
-- =============================================
create database CampingParadis;
go

use CampingParadis;
go


-- =============================================
-- =============================================
-- Création des données du magasin
-- =============================================
-- =============================================
create schema Magasin;
go

-- TODO:
-- * procédure 'vendre produit'
-- * procédure 'approvisionnement stock'
-- * procédure 'nouveau produit'
-- * procédure 'nouvelle gamme'
-- * procédure 'nouvelle famille' => paramètre 'parent' optionnel
-- * procédure 'nouvelle hiérarchie famille'

-- =============================================
-- Création des tables
-- =============================================

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
  IDMagasin int not null,
  IDProduit int not null,
  Prix money not null,
  Quantite int not null,
  DateVente DateTime not null,
  Vendeur varchar(64) not null
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

-- =============================================
-- Création des triggers
-- =============================================

-- Empêche d'avoir un stock négatif et met à jour l'attribut 'Epuise' de la table 'Magasin.Stock'.
-- '0' signifie que le stock est nul, '1' que le stock est faible, '2' que le stock est suffisant.
create trigger Magasin.trigger_quantite_stock
on Magasin.Stock
after insert, update
as
begin
  if update(Quantite) begin
    begin transaction
    declare @error bit;
    declare @IDMag int;
    declare @IDProd int;
    declare @Quantite int;
    declare @Epuise int;
    set @error = 0;
    declare cr_inserted cursor
    for select IDMagasin, IDProduit, Quantite
        from inserted;
    open cr_inserted;
    fetch cr_inserted into @IDMag, @IDProd, @Quantite;
    while(@@FETCH_STATUS = 0) begin
      if(@Quantite < 0) begin
        set @error = 1;
        break;
      end else if(@Quantite = 0) begin
        set @Epuise = 0;
      end else if(@Quantite < 5) begin
        set @Epuise = 1;
      end else begin
        set @Epuise = 2;
      end
      update Magasin.Stock
      set Epuise = @Epuise
      where IDMagasin = @IDMag and IDProduit = @IDProd;
      fetch cr_inserted into @IDMag, @IDProd, @Quantite;
    end
    close cr_inserted;
    deallocate cr_inserted;
    if(@error = 1) begin
      rollback;
    end else begin
      commit;
    end
  end
end;
go

-- Empêche toute modification de valeurs dans la tabe Magasin.HistoriqueVente. Seul l'ajout de données est autorisé
create trigger Magasin.trigger_historique_vente_non_modifiable
on Magasin.HistoriqueVente
after update, delete
as begin
  rollback
end;
go

-- =============================================
-- Création des triggers
-- =============================================

-- Vend un produit. Le stock sera diminué de la quantité vendue et l'historique de vente sera mis à jour.
CREATE PROCEDURE Magasin.VendreProduit
  @IDMagasin int,
  @IDProduit int,
  @Quantite int,
  @Vendeur varchar(64)
AS
BEGIN
	SET NOCOUNT ON;
  declare @InStock int;
  declare @QuantiteStock int;
  declare @Prix money;
  select @InStock = count(*) from Magasin.Stock where IDMagasin = @IDMagasin and IDProduit = @IDProduit;
  if @InStock = 1 begin
    select @QuantiteStock = Quantite from Magasin.Stock where IDMagasin = @IDMagasin and IDProduit = @IDProduit;
    if @QuantiteStock >= @Quantite begin
      update Magasin.Stock
      set Quantite = Quantite - @Quantite
      where IDMagasin = @IDMagasin and IDProduit = @IDProduit;
      select @Prix = PrixUnitaire
      from Magasin.Produit
      where ID = @IDProduit;
      insert into Magasin.HistoriqueVente (IDMagasin, IDProduit, Prix, Quantite, DateVente, Vendeur)
      values (@IDMagasin, @IDProduit, @Prix, @Quantite, GETDATE(), @Vendeur);
    end
  end
  -- valider quantité

END
GO
-- =============================================
-- Remplissage des tables du magasin
-- =============================================
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

-- =============================================
-- Ajout des contraintes sur les tables du magasin
-- =============================================
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
add constraint fk_historiquevente_magasin
foreign key (IDMagasin) references Magasin.Magasin (ID);

alter table Magasin.HistoriqueVente
add constraint fk_historiquevente_produit
foreign key (IDProduit) references Magasin.Produit (ID);
go

-- =============================================
-- Création des vues
-- =============================================

-- Affichage des familles avec leur parent
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