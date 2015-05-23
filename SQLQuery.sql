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
-- Création des données communes
-- =============================================
-- =============================================
create schema Commun;
go

-- =============================================
-- Création des tables
-- =============================================

create table Commun.Employe (
  ID int identity(1,1) primary key,
  Nom varchar(64) not null,
  Prenom varchar(64) not null,
);

-- =============================================
-- Remplissage des tables du magasin
-- =============================================

insert into Commun.Employe (Nom, Prenom)
values ('Perfect', 'Ford');
go

-- =============================================
-- =============================================
-- Création des données du magasin
-- =============================================
-- =============================================
create schema Magasin;
go

-- TODO:
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
  Telephone varchar(32),
  IDManager int not null
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
  IDVendeur int not null
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
-- Création des procédure
-- =============================================

-- Vend un produit. Le stock sera diminué de la quantité vendue et l'historique de vente sera mis à jour.
-- Si le stock est insuffisant, la vente ne sera par réalisée
CREATE PROCEDURE Magasin.VendreProduit
  @IDMagasin int,
  @IDProduit int,
  @Quantite int,
  @IDVendeur int
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
      select @Prix = PrixUnitaire
      from Magasin.Produit
      where ID = @IDProduit;
      begin transaction
      update Magasin.Stock
      set Quantite = Quantite - @Quantite
      where IDMagasin = @IDMagasin and IDProduit = @IDProduit;
      insert into Magasin.HistoriqueVente (IDMagasin, IDProduit, Prix, Quantite, DateVente, IDVendeur)
      values (@IDMagasin, @IDProduit, @Prix, @Quantite, GETDATE(), @IDVendeur);
      commit
    end
  end
END
GO

-- (R)ajoute un produit dans le stock
CREATE PROCEDURE Magasin.ApprovisionnerStock
  @IDMagasin int,
  @IDProduit int,
  @Quantite int
AS
BEGIN
	SET NOCOUNT ON;
  declare @present int;

  select @present = count(*) from Magasin.Stock where IDMagasin = @IDMagasin and IDProduit = @IDProduit;

  if @present = 0 begin
    insert into Magasin.Stock (IDMagasin, IDProduit, Quantite)
    values (@IDMagasin, @IDProduit, @Quantite);
  end else begin
    update Magasin.Stock
    set Quantite += @Quantite
    where IDMagasin = @IDMagasin and IDProduit = @IDProduit;
  end
END
GO

-- Crée un nouveau produit
CREATE PROCEDURE Magasin.NouveauProduit
	@Marque varchar(64),
  @PrixUnitaire money,
  @Contenance decimal(8,2),
  @Unite varchar(16),
  @IDGamme int,
  @IDMagasin int = null,
  @QuantiteStock int = null
AS
BEGIN
	SET NOCOUNT ON;
  declare @IDNouveauProduit int;

  insert into Magasin.Produit (Marque, PrixUnitaire, Contenance, Unite, IDGamme)
  values (@Marque, @PrixUnitaire, @Contenance, @Unite, @IDGamme);

  set @IDNouveauProduit = SCOPE_IDENTITY();

  if @IDMagasin is not null begin
    exec Magasin.ApprovisionnerStock @IDMagasin, @IDNouveauProduit, @QuantiteStock;
  end

  return @IDNouveauProduit;
END
GO

-- =============================================
-- Remplissage des tables du magasin
-- =============================================
declare @IDFamilleConserve int;
declare @IDFamilleConserveLegume int;
declare @IDFamilleLegume int;
declare @IDFamilleLegumeFrais int;
declare @IDFamilleLegumeSurgele int;
declare @IDGammePetitPoidsConserve int;
declare @IDMagasin int;
declare @IDProduitPetitPoidsConserveMarie400Gr int;
declare @IDProduitPetitPoidsConserveMarie800Gr int;
declare @IDProduitPetitPoidsConserveRene800Gr int;

insert into Magasin.Magasin (Nom, IDManager)
values ('La superette des Bellettes grises', 1);
set @IDMagasin = SCOPE_IDENTITY();

insert into Magasin.Famille (Libelle)
values ('Légumes');
set @IDFamilleLegume =  SCOPE_IDENTITY();
insert into Magasin.Famille (Libelle)
values ('Conserves');
set @IDFamilleConserve =  SCOPE_IDENTITY();
insert into Magasin.Famille (Libelle)
values ('Légumes frais');
set @IDFamilleLegumeFrais =  SCOPE_IDENTITY();
insert into Magasin.Famille (Libelle)
values ('Légumes surgelés');
set @IDFamilleLegumeSurgele =  SCOPE_IDENTITY();
insert into Magasin.Famille (Libelle)
values ('Conserves de légumes');
set @IDFamilleConserveLegume =  SCOPE_IDENTITY();

insert into Magasin.FamilleHerarchie (IDFamille,IDParent)
values(@IDFamilleLegumeFrais,
       @IDFamilleLegume);
insert into Magasin.FamilleHerarchie (IDFamille,IDParent)
values(@IDFamilleLegumeSurgele,
       @IDFamilleLegume);
insert into Magasin.FamilleHerarchie (IDFamille,IDParent)
values(@IDFamilleConserveLegume,
       @IDFamilleLegume);
insert into Magasin.FamilleHerarchie (IDFamille,IDParent)
values(@IDFamilleConserveLegume,
       @IDFamilleConserve);

insert into Magasin.Gamme(Libelle, IDFamille)
values('Petits pois en conserve',@IDFamilleConserveLegume);
set @IDGammePetitPoidsConserve =  SCOPE_IDENTITY();

exec @IDProduitPetitPoidsConserveMarie800Gr = Magasin.NouveauProduit 'Marie',1.25,800,'gr',@IDGammePetitPoidsConserve;
exec @IDProduitPetitPoidsConserveMarie400Gr = Magasin.NouveauProduit 'Marie',0.75,400,'gr',@IDGammePetitPoidsConserve;
exec @IDProduitPetitPoidsConserveRene800Gr = Magasin.NouveauProduit 'René',0.49,800,'gr',@IDGammePetitPoidsConserve;

exec Magasin.ApprovisionnerStock @IDMagasin, @IDProduitPetitPoidsConserveMarie800Gr, 25;
exec Magasin.ApprovisionnerStock @IDMagasin, @IDProduitPetitPoidsConserveMarie400Gr, 12;
exec Magasin.ApprovisionnerStock @IDMagasin, @IDProduitPetitPoidsConserveRene800Gr, 4;

-- =============================================
-- Ajout des contraintes sur les tables du magasin
-- =============================================
alter table Magasin.Magasin
add constraint fk_magasin_manager
foreign key (IDManager) references Commun.Employe (ID);

alter table Magasin.HistoriqueVente
add constraint fk_historiquevente_magasin
foreign key (IDMagasin) references Magasin.Magasin (ID);

alter table Magasin.HistoriqueVente
add constraint fk_historiquevente_produit
foreign key (IDProduit) references Magasin.Produit (ID);

alter table Magasin.HistoriqueVente
add constraint fk_historiquevente_vendeur
foreign key (IDVendeur) references Commun.Employe (ID);

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

alter table Magasin.Produit
add constraint uk_produit_unique
unique(Marque, Contenance, Unite, IDGamme);

alter table Magasin.Stock
add constraint fk_stock_produit
foreign key (IDProduit) references Magasin.Produit (ID);

alter table Magasin.Stock
add constraint fk_stock_magasin
foreign key (IDMagasin) references Magasin.Magasin (ID);
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