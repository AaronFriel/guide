{-# LANGUAGE
QuasiQuotes,
FlexibleContexts,
FlexibleInstances,
TypeFamilies,
OverloadedStrings,
NoImplicitPrelude
  #-}


{-# OPTIONS_GHC -fno-warn-orphans #-}


module Types
(
  Trait(..),
  ItemKind(..),
    hackageName,
  Item(..),
    pros,
    prosDeleted,
    cons,
    consDeleted,
    ecosystem,
    link,
    kind,
  Hue(..),
    hueToDarkColor,
    hueToLightColor,
  CategoryStatus(..),
  Category(..),
    title,
    status,
    prosConsEnabled,
    ecosystemEnabled,
    notesEnabled,
    groups,
    items,
    itemsDeleted,
    categorySlug,
  GlobalState(..),
    categories,
    categoriesDeleted,
    actions,
    pendingEdits,
    editIdCounter,
    findCategoryByItem,

  -- * Overloaded things
  uid,
  hasUid,
  content,
  name,
  description,
  notes,
  created,
  group_,

  -- * Edits
  Edit(..),
    isVacuousEdit,
  EditDetails(..),

  -- * Actions
  Action(..),
  Referrer(..),
  ActionDetails(..),

  -- * acid-state methods
  -- ** query
  GetGlobalState(..),
  GetCategories(..),
  GetCategory(..), GetCategoryMaybe(..),
  GetCategoryByItem(..),
  GetItem(..),
  GetTrait(..),

  -- ** add
  AddCategory(..),
  AddItem(..),
  AddPro(..),
  AddCon(..),

  -- ** set
  SetGlobalState(..),
  -- *** 'Category'
  SetCategoryTitle(..),
  SetCategoryGroup(..),
  SetCategoryNotes(..),
  SetCategoryStatus(..),
  SetCategoryProsConsEnabled(..),
  SetCategoryEcosystemEnabled(..),
  SetCategoryNotesEnabled(..),
  -- *** 'Item'
  SetItemName(..),
  SetItemLink(..),
  SetItemGroup(..),
  SetItemKind(..),
  SetItemDescription(..),
  SetItemNotes(..),
  SetItemEcosystem(..),
  -- *** 'Trait'
  SetTraitContent(..),

  -- ** delete
  DeleteCategory(..),
  DeleteItem(..),
  DeleteTrait(..),

  -- ** edits
  GetEdit(..), GetEdits(..),
  RegisterEdit(..),
  RemovePendingEdit(..), RemovePendingEdits(..),

  -- ** actions
  RegisterAction(..),

  -- ** other
  MoveItem(..),
  MoveTrait(..),
  RestoreCategory(..),
  RestoreItem(..),
  RestoreTrait(..),
  SetDirty(..), UnsetDirty(..),
  )
where


import BasePrelude hiding (Category)
-- Monads and monad transformers
import Control.Monad.State
import Control.Monad.Reader
-- Lenses
import Lens.Micro.Platform hiding ((&))
-- Containers
import qualified Data.Map as M
import Data.Map (Map)
-- Lists
import Data.List.Index
-- Text
import qualified Data.Text.All as T
import Data.Text.All (Text)
-- JSON
import qualified Data.Aeson as A
import qualified Data.Aeson.Types as A
-- Time
import Data.Time
-- Network
import Data.IP
-- acid-state
import Data.SafeCopy hiding (kind)
import Data.Acid as Acid

-- Local
import Utils
import SafeCopy
import Markdown


{- Note [extending types]
~~~~~~~~~~~~~~~~~~~~~~~~~

Here's what you should do if you add a new field to 'Trait', 'Item', or
'Category'.


Types.hs
~~~~~~~~~~~~~~~~~~~~~~~~~

  1. Fix all warnings about uninitialised fields that might appear (by
     e.g. providing a default value).

  2. Update the migration code; see Note [acid-state].

  3. If the field is user-editable: add a new constructor to 'Edit' and
     update the migration code for 'Edit'. Update 'isVacuousEdit', too.

  4. Create a method for updating the field (setSomethingField), add it to
     the “makeAcidic ''GlobalState” declaration, and export the
     SetSomethingField type.

  5. Export a lens for the field (if it shares the name with some other
     field, move it to the “* Overloaded things” heading).


Cache.hs
~~~~~~~~~~~~~~~~~~~~~~~~~

  1. If the field is non-trivial (e.g. “notes”) and it makes sense to cache
     it, add it to 'CacheKey'.

  2. Update 'cacheDepends'.


JS.hs
~~~~~~~~~~~~~~~~~~~~~~~~~

  1. If the field is user-editable, add a method for setting it and don't
     forget to add it to the 'allJSFunctions' list.


View.hs
~~~~~~~~~~~~~~~~~~~~~~~~~

  1. If the field is non-trivial, add a method for rendering it.

  2. Don't forget to actually render it if the user is supposed to see it.

  3. Add a branch for the constructor you made in Types.hs/#3 to 'renderEdit'.


Guide.hs
~~~~~~~~~~~~~~~~~~~~~~~~~

  1. Add a case to 'invalidateCacheForEdit'.

  2. Add a case to 'undoEdit'.

  3. If the field is user-editable, add a method for changing it to
     'setMethods'.

-}

-- If you want to add a field here, see Note [extending types]
data Trait = Trait {
  _traitUid :: Uid Trait,
  _traitContent :: MarkdownInline }
  deriving (Show, Generic)

-- See Note [acid-state]
deriveSafeCopySorted 4 'extension ''Trait
makeFields ''Trait

changelog ''Trait (Current 4, Past 3) []
deriveSafeCopySorted 3 'base ''Trait_v3

instance A.ToJSON Trait where
  toJSON = A.genericToJSON A.defaultOptions {
    A.fieldLabelModifier = over _head toLower . drop (T.length "_trait") }

--

data ItemKind
  = Library {_itemKindHackageName :: Maybe Text}
  | Tool {_itemKindHackageName :: Maybe Text}
  | Other
  deriving (Eq, Show, Generic)

deriveSafeCopySimple 3 'extension ''ItemKind
makeFields ''ItemKind

instance A.ToJSON ItemKind where
  toJSON = A.genericToJSON A.defaultOptions {
    A.fieldLabelModifier = over _head toLower . drop (T.length "_itemKind") }

data ItemKind_v2
  = Library_v2 {_itemKindHackageName_v2 :: Maybe Text}
  | Tool_v2 {_itemKindHackageName_v2 :: Maybe Text}
  | Other_v2

-- TODO: at the next migration change this to deriveSafeCopySimple!
deriveSafeCopy 2 'base ''ItemKind_v2

instance Migrate ItemKind where
  type MigrateFrom ItemKind = ItemKind_v2
  migrate Library_v2{..} = Library {
    _itemKindHackageName = _itemKindHackageName_v2 }
  migrate Tool_v2{..} = Tool {
    _itemKindHackageName = _itemKindHackageName_v2 }
  migrate Other_v2 = Other

--

-- TODO: add a field like “people to ask on IRC about this library if you
-- need help”

-- If you want to add a field here, see Note [extending types]
data Item = Item {
  _itemUid         :: Uid Item,
  _itemName        :: Text,
  _itemCreated     :: UTCTime,
  _itemGroup_      :: Maybe Text,
  _itemDescription :: MarkdownBlock,
  _itemPros        :: [Trait],
  _itemProsDeleted :: [Trait],
  _itemCons        :: [Trait],
  _itemConsDeleted :: [Trait],
  _itemEcosystem   :: MarkdownBlock,
  _itemNotes       :: MarkdownBlockWithTOC,
  _itemLink        :: Maybe Url,
  _itemKind        :: ItemKind }
  deriving (Show, Generic)

deriveSafeCopySorted 11 'extension ''Item
makeFields ''Item

changelog ''Item (Current 11, Past 10) []
deriveSafeCopySorted 10 'base ''Item_v10

instance A.ToJSON Item where
  toJSON = A.genericToJSON A.defaultOptions {
    A.fieldLabelModifier = over _head toLower . drop (T.length "_item") }

--

data Hue = NoHue | Hue Int
  deriving (Eq, Ord)

deriveSafeCopySimple 1 'extension ''Hue

instance A.ToJSON Hue where
  toJSON NoHue = A.toJSON (0 :: Int)
  toJSON (Hue n) = A.toJSON n

data Hue_v0 = NoHue_v0 | Hue_v0 Int

-- TODO: at the next migration change this to deriveSafeCopySimple!
deriveSafeCopy 0 'base ''Hue_v0

instance Migrate Hue where
  type MigrateFrom Hue = Hue_v0
  migrate NoHue_v0 = NoHue
  migrate (Hue_v0 i) = Hue i

instance Show Hue where
  show NoHue   = "0"
  show (Hue n) = show n

-- Colors taken from:
-- <https://www.google.com/design/spec/style/color.html#color-color-palette>
hueToDarkColor :: Hue -> Text
hueToDarkColor NoHue = "#D6D6D6"  -- the color for gray isn't from Google's
                                  -- palette, since their “100” is too light
hueToDarkColor (Hue i) = table !! ((i-1) `mod` length table)
  where
    -- the “100” colors
    table = ["#D1C4E9",   -- deep purple
             "#C8E6C9",   -- green
             "#FFECB3",   -- amber
             "#BBDEFB",   -- blue
             "#FFCDD2",   -- red
             "#D7CCC8",   -- brown
             "#B2DFDB",   -- teal
             "#F0F4C3"]   -- lime

hueToLightColor :: Hue -> Text
hueToLightColor NoHue = "#F0F0F0"  -- the color for gray isn't from Google's
                                   -- palette, since their “50” is too light
hueToLightColor (Hue i) = table !! ((i-1) `mod` length table)
  where
    -- the “50” colors
    table = ["#EDE7F6",   -- deep purple
             "#E8F5E9",   -- green
             "#FFF8E1",   -- amber
             "#E3F2FD",   -- blue
             "#FFEBEE",   -- red
             "#EFEBE9",   -- brown
             "#E0F2F1",   -- teal
             "#F9FBE7"]   -- lime

--

data CategoryStatus
  = CategoryStub
  | CategoryWIP
  | CategoryFinished
  deriving (Eq, Show, Generic)

deriveSafeCopySimple 2 'extension ''CategoryStatus

instance A.ToJSON CategoryStatus where
  toJSON = A.genericToJSON A.defaultOptions

data CategoryStatus_v1
  = CategoryStub_v1
  | CategoryWIP_v1
  | CategoryMostlyDone_v1
  | CategoryFinished_v1

deriveSafeCopySimple 1 'base ''CategoryStatus_v1

instance Migrate CategoryStatus where
  type MigrateFrom CategoryStatus = CategoryStatus_v1
  migrate CategoryStub_v1 = CategoryStub
  migrate CategoryWIP_v1 = CategoryWIP
  migrate CategoryMostlyDone_v1 = CategoryFinished
  migrate CategoryFinished_v1 = CategoryFinished

-- If you want to add a field here, see Note [extending types]
data Category = Category {
  _categoryUid :: Uid Category,
  _categoryTitle :: Text,
  -- | The “grandcategory” of the category (“meta”, “basics”, “specialised
  -- needs”, etc)
  _categoryGroup_ :: Text,
  -- | Whether to show items' pros and cons. This would be 'False' for
  -- e.g. lists of people, or lists of successful projects written in Haskell
  _categoryProsConsEnabled :: Bool,
  -- | Whether to show items' ecosystem fields. This would be 'False' for
  -- lists of people, or for books
  _categoryEcosystemEnabled :: Bool,
  -- | Whether to show notes.
  _categoryNotesEnabled :: Bool,
  _categoryCreated :: UTCTime,
  _categoryStatus :: CategoryStatus,
  _categoryNotes :: MarkdownBlock,
  -- | All groups of items belonging to the category, as well as their
  -- colors. We could assign colors to items when we render the category
  -- (something like “if haven't seen this group yet, assign a new color to
  -- it and render it with this color”, but this way is easier and also
  -- allows us to keep the colors of all other groups the same when one item
  -- has been deleted.
  _categoryGroups :: Map Text Hue,
  _categoryItems :: [Item],
  _categoryItemsDeleted :: [Item] }
  deriving (Show, Generic)

deriveSafeCopySorted 10 'extension ''Category
makeFields ''Category

changelog ''Category (Current 10, Past 9)
  [Added "_categoryNotesEnabled" [hs|True|]]
deriveSafeCopySorted 9 'base ''Category_v9

changelog ''Category (Past 9, Past 8) []
deriveSafeCopySorted 8 'base ''Category_v8

instance A.ToJSON Category where
  toJSON = A.genericToJSON A.defaultOptions {
    A.fieldLabelModifier = over _head toLower . drop (T.length "_category") }

categorySlug :: Category -> Text
categorySlug category =
  T.format "{}-{}" (makeSlug (category^.title), category^.uid)

-- Edits

-- | Edits made by users. It should always be possible to undo an edit.
data Edit
  -- Add
  = Edit'AddCategory {
      editCategoryUid   :: Uid Category,
      editCategoryTitle :: Text }
  | Edit'AddItem {
      editCategoryUid   :: Uid Category,
      editItemUid       :: Uid Item,
      editItemName      :: Text }
  | Edit'AddPro {
      editItemUid       :: Uid Item,
      editTraitId       :: Uid Trait,
      editTraitContent  :: Text }
  | Edit'AddCon {
      editItemUid       :: Uid Item,
      editTraitId       :: Uid Trait,
      editTraitContent  :: Text }

  -- Change category properties
  | Edit'SetCategoryTitle {
      editCategoryUid       :: Uid Category,
      editCategoryTitle     :: Text,
      editCategoryNewTitle  :: Text }
  | Edit'SetCategoryGroup {
      editCategoryUid       :: Uid Category,
      editCategoryGroup     :: Text,
      editCategoryNewGroup  :: Text }
  | Edit'SetCategoryNotes {
      editCategoryUid       :: Uid Category,
      editCategoryNotes     :: Text,
      editCategoryNewNotes  :: Text }
  | Edit'SetCategoryStatus {
      editCategoryUid       :: Uid Category,
      editCategoryStatus    :: CategoryStatus,
      editCategoryNewStatus :: CategoryStatus }
  | Edit'SetCategoryProsConsEnabled {
      editCategoryUid                 :: Uid Category,
      editCategoryProsConsEnabled     :: Bool,
      editCategoryNewProsConsEnabled  :: Bool }
  | Edit'SetCategoryEcosystemEnabled {
      editCategoryUid                 :: Uid Category,
      editCategoryEcosystemEnabled    :: Bool,
      editCategoryNewEcosystemEnabled :: Bool }
  | Edit'SetCategoryNotesEnabled {
      editCategoryUid                 :: Uid Category,
      editCategoryNotesEnabled        :: Bool,
      editCategoryNewNotesEnabled     :: Bool }

  -- Change item properties
  | Edit'SetItemName {
      editItemUid            :: Uid Item,
      editItemName           :: Text,
      editItemNewName        :: Text }
  | Edit'SetItemLink {
      editItemUid            :: Uid Item,
      editItemLink           :: Maybe Url,
      editItemNewLink        :: Maybe Url }
  | Edit'SetItemGroup {
      editItemUid            :: Uid Item,
      editItemGroup          :: Maybe Text,
      editItemNewGroup       :: Maybe Text }
  | Edit'SetItemKind {
      editItemUid            :: Uid Item,
      editItemKind           :: ItemKind,
      editItemNewKind        :: ItemKind }
  | Edit'SetItemDescription {
      editItemUid            :: Uid Item,
      editItemDescription    :: Text,
      editItemNewDescription :: Text }
  | Edit'SetItemNotes {
      editItemUid            :: Uid Item,
      editItemNotes          :: Text,
      editItemNewNotes       :: Text }
  | Edit'SetItemEcosystem {
      editItemUid            :: Uid Item,
      editItemEcosystem      :: Text,
      editItemNewEcosystem   :: Text }

  -- Change trait properties
  | Edit'SetTraitContent {
      editItemUid         :: Uid Item,
      editTraitUid        :: Uid Trait,
      editTraitContent    :: Text,
      editTraitNewContent :: Text }

  -- Delete
  | Edit'DeleteCategory {
      editCategoryUid       :: Uid Category,
      editCategoryPosition  :: Int }
  | Edit'DeleteItem {
      editItemUid           :: Uid Item,
      editItemPosition      :: Int }
  | Edit'DeleteTrait {
      editItemUid           :: Uid Item,
      editTraitUid          :: Uid Trait,
      editTraitPosition     :: Int }

  -- Other
  | Edit'MoveItem {
      editItemUid   :: Uid Item,
      editDirection :: Bool }
  | Edit'MoveTrait {
      editItemUid   :: Uid Item,
      editTraitUid  :: Uid Trait,
      editDirection :: Bool }

  deriving (Eq, Show)

deriveSafeCopySimple 6 'extension ''Edit

genVer ''Edit 5 [
  -- Add
  Copy 'Edit'AddCategory,
  Copy 'Edit'AddItem,
  Copy 'Edit'AddPro,
  Copy 'Edit'AddCon,
  -- Change category properties
  Copy 'Edit'SetCategoryTitle,
  Copy 'Edit'SetCategoryGroup,
  Copy 'Edit'SetCategoryNotes,
  Copy 'Edit'SetCategoryStatus,
  Copy 'Edit'SetCategoryProsConsEnabled,
  Copy 'Edit'SetCategoryEcosystemEnabled,
  -- Copy 'Edit'SetCategoryNotesEnabled,
  -- Change item properties
  Copy 'Edit'SetItemName,
  Copy 'Edit'SetItemLink,
  Copy 'Edit'SetItemGroup,
  Copy 'Edit'SetItemKind,
  Copy 'Edit'SetItemDescription,
  Copy 'Edit'SetItemNotes,
  Copy 'Edit'SetItemEcosystem,
  -- Change trait properties
  Copy 'Edit'SetTraitContent,
  -- Delete
  Copy 'Edit'DeleteCategory,
  Copy 'Edit'DeleteItem,
  Copy 'Edit'DeleteTrait,
  -- Other
  Copy 'Edit'MoveItem,
  Copy 'Edit'MoveTrait ]

deriveSafeCopySimple 5 'base ''Edit_v5

instance Migrate Edit where
  type MigrateFrom Edit = Edit_v5
  migrate = $(migrateVer ''Edit 5 [
    CopyM 'Edit'AddCategory,
    CopyM 'Edit'AddItem,
    CopyM 'Edit'AddPro,
    CopyM 'Edit'AddCon,
    -- Change category properties
    CopyM 'Edit'SetCategoryTitle,
    CopyM 'Edit'SetCategoryGroup,
    CopyM 'Edit'SetCategoryNotes,
    CopyM 'Edit'SetCategoryStatus,
    CopyM 'Edit'SetCategoryProsConsEnabled,
    CopyM 'Edit'SetCategoryEcosystemEnabled,
    -- CopyM 'Edit'SetCategoryNotesEnabled,
    -- Change item properties
    CopyM 'Edit'SetItemName,
    CopyM 'Edit'SetItemLink,
    CopyM 'Edit'SetItemGroup,
    CopyM 'Edit'SetItemKind,
    CopyM 'Edit'SetItemDescription,
    CopyM 'Edit'SetItemNotes,
    CopyM 'Edit'SetItemEcosystem,
    -- Change trait properties
    CopyM 'Edit'SetTraitContent,
    -- Delete
    CopyM 'Edit'DeleteCategory,
    CopyM 'Edit'DeleteItem,
    CopyM 'Edit'DeleteTrait,
    -- Other
    CopyM 'Edit'MoveItem,
    CopyM 'Edit'MoveTrait
    ])

-- | Determine whether the edit doesn't actually change anything and so isn't
-- worth recording in the list of pending edits.
isVacuousEdit :: Edit -> Bool
isVacuousEdit Edit'SetCategoryTitle{..} =
  editCategoryTitle == editCategoryNewTitle
isVacuousEdit Edit'SetCategoryGroup{..} =
  editCategoryGroup == editCategoryNewGroup
isVacuousEdit Edit'SetCategoryNotes{..} =
  editCategoryNotes == editCategoryNewNotes
isVacuousEdit Edit'SetCategoryStatus{..} =
  editCategoryStatus == editCategoryNewStatus
isVacuousEdit Edit'SetCategoryProsConsEnabled {..} =
  editCategoryProsConsEnabled == editCategoryNewProsConsEnabled
isVacuousEdit Edit'SetCategoryEcosystemEnabled {..} =
  editCategoryEcosystemEnabled == editCategoryNewEcosystemEnabled
isVacuousEdit Edit'SetCategoryNotesEnabled {..} =
  editCategoryNotesEnabled == editCategoryNewNotesEnabled
isVacuousEdit Edit'SetItemName{..} =
  editItemName == editItemNewName
isVacuousEdit Edit'SetItemLink{..} =
  editItemLink == editItemNewLink
isVacuousEdit Edit'SetItemGroup{..} =
  editItemGroup == editItemNewGroup
isVacuousEdit Edit'SetItemKind{..} =
  editItemKind == editItemNewKind
isVacuousEdit Edit'SetItemDescription{..} =
  editItemDescription == editItemNewDescription
isVacuousEdit Edit'SetItemNotes{..} =
  editItemNotes == editItemNewNotes
isVacuousEdit Edit'SetItemEcosystem{..} =
  editItemEcosystem == editItemNewEcosystem
isVacuousEdit Edit'SetTraitContent{..} =
  editTraitContent == editTraitNewContent
isVacuousEdit Edit'AddCategory{}    = False
isVacuousEdit Edit'AddItem{}        = False
isVacuousEdit Edit'AddPro{}         = False
isVacuousEdit Edit'AddCon{}         = False
isVacuousEdit Edit'DeleteCategory{} = False
isVacuousEdit Edit'DeleteItem{}     = False
isVacuousEdit Edit'DeleteTrait{}    = False
isVacuousEdit Edit'MoveItem{}       = False
isVacuousEdit Edit'MoveTrait{}      = False

data EditDetails = EditDetails {
  editIP   :: Maybe IP,
  editDate :: UTCTime,
  editId   :: Int }
  deriving (Eq, Show)

deriveSafeCopySorted 4 'extension ''EditDetails

changelog ''EditDetails (Current 4, Past 3) []
deriveSafeCopySorted 3 'base ''EditDetails_v3

data Action
  = Action'MainPageVisit
  | Action'CategoryVisit (Uid Category)
  | Action'Search Text
  | Action'Edit Edit
  deriving (Show)

deriveSafeCopySimple 0 'base ''Action

data Referrer = InternalReferrer Url | ExternalReferrer Url
  deriving (Show, Eq)

deriveSafeCopySimple 0 'base ''Referrer

data ActionDetails = ActionDetails {
  actionIP        :: Maybe IP,
  actionDate      :: UTCTime,
  actionReferrer  :: Maybe Referrer,
  actionUserAgent :: Maybe Text }
  deriving (Show)

deriveSafeCopySorted 3 'extension ''ActionDetails

changelog ''ActionDetails (Current 3, Past 2) []
deriveSafeCopySorted 2 'base ''ActionDetails_v2

-- See Note [acid-state]

data GlobalState = GlobalState {
  _categories :: [Category],
  _categoriesDeleted :: [Category],
  _actions :: [(Action, ActionDetails)],
  -- | Pending edits, newest first
  _pendingEdits :: [(Edit, EditDetails)],
  -- | ID of next edit that will be made
  _editIdCounter :: Int,
  -- | The dirty bit (needed to choose whether to make a checkpoint or not)
  _dirty :: Bool }
  deriving (Show)

deriveSafeCopySorted 7 'extension ''GlobalState
makeLenses ''GlobalState

changelog ''GlobalState (Current 7, Past 6) []
deriveSafeCopySorted 6 'base ''GlobalState_v6

addGroupIfDoesNotExist :: Text -> Map Text Hue -> Map Text Hue
addGroupIfDoesNotExist g gs
  | M.member g gs = gs
  | otherwise     = M.insert g firstNotTaken gs
  where
    firstNotTaken = head $ map Hue [1..] \\ M.elems gs

traitById :: Uid Trait -> Lens' Item Trait
traitById uid' = singular $
  (pros.each . filtered (hasUid uid')) `failing`
  (cons.each . filtered (hasUid uid')) `failing`
  error ("traitById: couldn't find trait with uid " ++
         T.unpack (uidToText uid'))

categoryById :: Uid Category -> Lens' GlobalState Category
categoryById catId = singular $
  categories.each . filtered (hasUid catId) `failing`
  error ("categoryById: couldn't find category with uid " ++
         T.unpack (uidToText catId))

itemById :: Uid Item -> Lens' GlobalState Item
itemById itemId = singular $
  categories.each . items.each . filtered (hasUid itemId) `failing`
  error ("itemById: couldn't find item with uid " ++
         T.unpack (uidToText itemId))

findCategoryByItem :: Uid Item -> GlobalState -> Category
findCategoryByItem itemId s =
  fromMaybe (error err) (find hasItem (s^.categories))
  where
    err = "findCategoryByItem: couldn't find category with item with uid " ++
          T.unpack (uidToText itemId)
    hasItem category = itemId `elem` (category^..items.each.uid)

hasUid :: HasUid a (Uid u) => Uid u -> a -> Bool
hasUid u x = x^.uid == u

-- get

getGlobalState :: Acid.Query GlobalState GlobalState
getGlobalState = view id

getCategories :: Acid.Query GlobalState [Category]
getCategories = view categories

getCategory :: Uid Category -> Acid.Query GlobalState Category
getCategory uid' = view (categoryById uid')

getCategoryMaybe :: Uid Category -> Acid.Query GlobalState (Maybe Category)
getCategoryMaybe uid' = preview (categoryById uid')

getCategoryByItem :: Uid Item -> Acid.Query GlobalState Category
getCategoryByItem uid' = findCategoryByItem uid' <$> ask

getItem :: Uid Item -> Acid.Query GlobalState Item
getItem uid' = view (itemById uid')

-- TODO: this doesn't need the item id, but then we have to be a bit cleverer
-- and store a (TraitId -> ItemId) map in global state (and update it
-- accordingly whenever anything happens, so perhaps let's not do it!)
getTrait :: Uid Item -> Uid Trait -> Acid.Query GlobalState Trait
getTrait itemId traitId = view (itemById itemId . traitById traitId)

-- add

addCategory
  :: Uid Category    -- ^ New category's id
  -> Text            -- ^ Title
  -> UTCTime         -- ^ Creation time
  -> Acid.Update GlobalState (Edit, Category)
addCategory catId title' created' = do
  let newCategory = Category {
        _categoryUid = catId,
        _categoryTitle = title',
        _categoryGroup_ = "Miscellaneous",
        _categoryProsConsEnabled = True,
        _categoryEcosystemEnabled = True,
        _categoryNotesEnabled = True,
        _categoryCreated = created',
        _categoryStatus = CategoryStub,
        _categoryNotes = toMarkdownBlock "",
        _categoryGroups = mempty,
        _categoryItems = [],
        _categoryItemsDeleted = [] }
  categories %= (newCategory :)
  let edit = Edit'AddCategory catId title'
  return (edit, newCategory)

addItem
  :: Uid Category    -- ^ Category id
  -> Uid Item        -- ^ New item's id
  -> Text            -- ^ Name
  -> UTCTime         -- ^ Creation time
  -> ItemKind        -- ^ Kind
  -> Acid.Update GlobalState (Edit, Item)
addItem catId itemId name' created' kind' = do
  let newItem = Item {
        _itemUid         = itemId,
        _itemName        = name',
        _itemCreated     = created',
        _itemGroup_      = Nothing,
        _itemDescription = toMarkdownBlock "",
        _itemPros        = [],
        _itemProsDeleted = [],
        _itemCons        = [],
        _itemConsDeleted = [],
        _itemEcosystem   = toMarkdownBlock "",
        _itemNotes       = let pref = "item-notes-" <> uidToText itemId <> "-"
                           in  toMarkdownBlockWithTOC pref "",
        _itemLink        = Nothing,
        _itemKind        = kind' }
  categoryById catId . items %= (++ [newItem])
  let edit = Edit'AddItem catId itemId name'
  return (edit, newItem)

addPro
  :: Uid Item       -- ^ Item id
  -> Uid Trait      -- ^ New trait's id
  -> Text
  -> Acid.Update GlobalState (Edit, Trait)
addPro itemId traitId text' = do
  let newTrait = Trait traitId (toMarkdownInline text')
  itemById itemId . pros %= (++ [newTrait])
  let edit = Edit'AddPro itemId traitId text'
  return (edit, newTrait)

addCon
  :: Uid Item       -- ^ Item id
  -> Uid Trait      -- ^ New trait's id
  -> Text
  -> Acid.Update GlobalState (Edit, Trait)
addCon itemId traitId text' = do
  let newTrait = Trait traitId (toMarkdownInline text')
  itemById itemId . cons %= (++ [newTrait])
  let edit = Edit'AddCon itemId traitId text'
  return (edit, newTrait)

-- set

-- Almost all of these return an 'Edit' that corresponds to the edit that has
-- been performed.

-- | Can be useful sometimes (e.g. if you want to regenerate all uids), but
-- generally shouldn't be used.
setGlobalState :: GlobalState -> Acid.Update GlobalState ()
setGlobalState = (id .=)

setCategoryTitle :: Uid Category -> Text -> Acid.Update GlobalState (Edit, Category)
setCategoryTitle catId title' = do
  oldTitle <- categoryById catId . title <<.= title'
  let edit = Edit'SetCategoryTitle catId oldTitle title'
  (edit,) <$> use (categoryById catId)

setCategoryGroup :: Uid Category -> Text -> Acid.Update GlobalState (Edit, Category)
setCategoryGroup catId group' = do
  oldGroup <- categoryById catId . group_ <<.= group'
  let edit = Edit'SetCategoryGroup catId oldGroup group'
  (edit,) <$> use (categoryById catId)

setCategoryNotes :: Uid Category -> Text -> Acid.Update GlobalState (Edit, Category)
setCategoryNotes catId notes' = do
  oldNotes <- categoryById catId . notes <<.= toMarkdownBlock notes'
  let edit = Edit'SetCategoryNotes catId (oldNotes ^. mdText) notes'
  (edit,) <$> use (categoryById catId)

setCategoryStatus :: Uid Category -> CategoryStatus -> Acid.Update GlobalState (Edit, Category)
setCategoryStatus catId status' = do
  oldStatus <- categoryById catId . status <<.= status'
  let edit = Edit'SetCategoryStatus catId oldStatus status'
  (edit,) <$> use (categoryById catId)

setCategoryProsConsEnabled
  :: Uid Category -> Bool -> Acid.Update GlobalState (Edit, Category)
setCategoryProsConsEnabled catId val = do
  oldVal <- categoryById catId . prosConsEnabled <<.= val
  let edit = Edit'SetCategoryProsConsEnabled catId oldVal val
  (edit,) <$> use (categoryById catId)

setCategoryEcosystemEnabled
  :: Uid Category -> Bool -> Acid.Update GlobalState (Edit, Category)
setCategoryEcosystemEnabled catId val = do
  oldVal <- categoryById catId . ecosystemEnabled <<.= val
  let edit = Edit'SetCategoryEcosystemEnabled catId oldVal val
  (edit,) <$> use (categoryById catId)

setCategoryNotesEnabled
  :: Uid Category -> Bool -> Acid.Update GlobalState (Edit, Category)
setCategoryNotesEnabled catId val = do
  oldVal <- categoryById catId . notesEnabled <<.= val
  let edit = Edit'SetCategoryNotesEnabled catId oldVal val
  (edit,) <$> use (categoryById catId)

setItemName :: Uid Item -> Text -> Acid.Update GlobalState (Edit, Item)
setItemName itemId name' = do
  oldName <- itemById itemId . name <<.= name'
  let edit = Edit'SetItemName itemId oldName name'
  (edit,) <$> use (itemById itemId)

setItemLink :: Uid Item -> Maybe Url -> Acid.Update GlobalState (Edit, Item)
setItemLink itemId link' = do
  oldLink <- itemById itemId . link <<.= link'
  let edit = Edit'SetItemLink itemId oldLink link'
  (edit,) <$> use (itemById itemId)

-- Also updates the list of groups in the category
setItemGroup :: Uid Item -> Maybe Text -> Acid.Update GlobalState (Edit, Item)
setItemGroup itemId newGroup = do
  catId <- view uid . findCategoryByItem itemId <$> get
  let categoryLens :: Lens' GlobalState Category
      categoryLens = categoryById catId
  let itemLens :: Lens' GlobalState Item
      itemLens = itemById itemId
  -- If the group is new, add it to the list of groups in the category (which
  -- causes a new hue to be generated, too)
  case newGroup of
    Nothing -> return ()
    Just x  -> categoryLens.groups %= addGroupIfDoesNotExist x
  -- Update list of groups if the group is going to be empty after the item
  -- is moved to a different group. Note that this is done after adding a new
  -- group because we also want the color to change. So, if the item was the
  -- only item in its group, the sequence of actions is as follows:
  -- 
  --   * new group is added (and hence a new color is assigned)
  --   * old group is deleted (and now the old color is unused)
  oldGroup <- use (itemLens.group_)
  case oldGroup of
    Nothing -> return ()
    Just g  -> when (oldGroup /= newGroup) $ do
      allItems <- use (categoryLens.items)
      let inOurGroup item = item^.group_ == Just g
      when (length (filter inOurGroup allItems) == 1) $
        categoryLens.groups %= M.delete g
  -- Now we can actually change the group
  itemLens.group_ .= newGroup
  let edit = Edit'SetItemGroup itemId oldGroup newGroup
  (edit,) <$> use itemLens

setItemKind :: Uid Item -> ItemKind -> Acid.Update GlobalState (Edit, Item)
setItemKind itemId kind' = do
  oldKind <- itemById itemId . kind <<.= kind'
  let edit = Edit'SetItemKind itemId oldKind kind'
  (edit,) <$> use (itemById itemId)

setItemDescription :: Uid Item -> Text -> Acid.Update GlobalState (Edit, Item)
setItemDescription itemId description' = do
  oldDescr <- itemById itemId . description <<.=
                toMarkdownBlock description'
  let edit = Edit'SetItemDescription itemId
               (oldDescr ^. mdText) description'
  (edit,) <$> use (itemById itemId)

setItemNotes :: Uid Item -> Text -> Acid.Update GlobalState (Edit, Item)
setItemNotes itemId notes' = do
  let pref = "item-notes-" <> uidToText itemId <> "-"
  oldNotes <- itemById itemId . notes <<.=
                toMarkdownBlockWithTOC pref notes'
  let edit = Edit'SetItemNotes itemId (oldNotes ^. mdText) notes'
  (edit,) <$> use (itemById itemId)

setItemEcosystem :: Uid Item -> Text -> Acid.Update GlobalState (Edit, Item)
setItemEcosystem itemId ecosystem' = do
  oldEcosystem <- itemById itemId . ecosystem <<.=
                    toMarkdownBlock ecosystem'
  let edit = Edit'SetItemEcosystem itemId
               (oldEcosystem ^. mdText) ecosystem'
  (edit,) <$> use (itemById itemId)

setTraitContent :: Uid Item -> Uid Trait -> Text -> Acid.Update GlobalState (Edit, Trait)
setTraitContent itemId traitId content' = do
  oldContent <- itemById itemId . traitById traitId . content <<.=
                  toMarkdownInline content'
  let edit = Edit'SetTraitContent itemId traitId
               (oldContent ^. mdText) content'
  (edit,) <$> use (itemById itemId . traitById traitId)

-- delete

deleteCategory :: Uid Category -> Acid.Update GlobalState (Either String Edit)
deleteCategory catId = do
  mbCategory <- preuse (categoryById catId)
  case mbCategory of
    Nothing       -> return (Left "category not found")
    Just category -> do
      mbCategoryPos <- findIndex (hasUid catId) <$> use categories
      case mbCategoryPos of
        Nothing          -> return (Left "category not found")
        Just categoryPos -> do
          categories %= deleteAt categoryPos
          categoriesDeleted %= (category:)
          return (Right (Edit'DeleteCategory catId categoryPos))

deleteItem :: Uid Item -> Acid.Update GlobalState (Either String Edit)
deleteItem itemId = do
  catId <- view uid . findCategoryByItem itemId <$> get
  let categoryLens :: Lens' GlobalState Category
      categoryLens = categoryById catId
  let itemLens :: Lens' GlobalState Item
      itemLens = itemById itemId
  mbItem <- preuse itemLens
  case mbItem of
    Nothing   -> return (Left "item not found")
    Just item -> do
      allItems <- use (categoryLens.items)
      -- If the item was the only item in its group, delete the group (and
      -- make the hue available for new items)
      case item^.group_ of
        Nothing       -> return ()
        Just oldGroup -> do
          let itemsInOurGroup = [item' | item' <- allItems,
                                         item'^.group_ == Just oldGroup]
          when (length itemsInOurGroup == 1) $
            categoryLens.groups %= M.delete oldGroup
      -- And now delete the item (i.e. move it to “deleted”)
      case findIndex (hasUid itemId) allItems of
        Nothing      -> return (Left "item not found")
        Just itemPos -> do
          categoryLens.items        %= deleteAt itemPos
          categoryLens.itemsDeleted %= (item:)
          return (Right (Edit'DeleteItem itemId itemPos))

deleteTrait :: Uid Item -> Uid Trait -> Acid.Update GlobalState (Either String Edit)
deleteTrait itemId traitId = do
  let itemLens :: Lens' GlobalState Item
      itemLens = itemById itemId
  mbItem <- preuse itemLens
  case mbItem of
    Nothing   -> return (Left "item not found")
    Just item -> do
      -- Determine whether the trait is a pro or a con, and proceed
      -- accordingly
      case (find (hasUid traitId) (item^.pros),
            find (hasUid traitId) (item^.cons)) of
        -- It's in neither group, which means it was deleted. Do nothing.
        (Nothing, Nothing) -> return (Left "trait not found")
        -- It's a pro
        (Just trait, _) -> do
          mbTraitPos <- findIndex (hasUid traitId) <$> use (itemLens.pros)
          case mbTraitPos of
            Nothing       -> return (Left "trait not found")
            Just traitPos -> do
              itemLens.pros        %= deleteAt traitPos
              itemLens.prosDeleted %= (trait:)
              return (Right (Edit'DeleteTrait itemId traitId traitPos))
        -- It's a con
        (_, Just trait) -> do
          mbTraitPos <- findIndex (hasUid traitId) <$> use (itemLens.cons)
          case mbTraitPos of
            Nothing       -> return (Left "trait not found")
            Just traitPos -> do
              itemLens.cons        %= deleteAt traitPos
              itemLens.consDeleted %= (trait:)
              return (Right (Edit'DeleteTrait itemId traitId traitPos))

-- other methods

moveItem
  :: Uid Item
  -> Bool       -- ^ 'True' means up, 'False' means down
  -> Acid.Update GlobalState Edit
moveItem itemId up = do
  let move = if up then moveUp else moveDown
  catId <- view uid . findCategoryByItem itemId <$> get
  categoryById catId . items %= move (hasUid itemId)
  return (Edit'MoveItem itemId up)

moveTrait
  :: Uid Item
  -> Uid Trait
  -> Bool        -- ^ 'True' means up, 'False' means down
  -> Acid.Update GlobalState Edit
moveTrait itemId traitId up = do
  let move = if up then moveUp else moveDown
  -- The trait is only going to be present in one of the lists so let's do it
  -- in each list because we're too lazy to figure out whether it's a pro or
  -- a con
  itemById itemId . pros %= move (hasUid traitId)
  itemById itemId . cons %= move (hasUid traitId)
  return (Edit'MoveTrait itemId traitId up)

restoreCategory :: Uid Category -> Int -> Acid.Update GlobalState (Either String ())
restoreCategory catId pos = do
  deleted <- use categoriesDeleted
  case find (hasUid catId) deleted of
    Nothing -> return (Left "category not found in deleted categories")
    Just category -> do
      categoriesDeleted %= deleteFirst (hasUid catId)
      categories        %= insertAtGuaranteed pos category
      return (Right ())

restoreItem :: Uid Item -> Int -> Acid.Update GlobalState (Either String ())
restoreItem itemId pos = do
  let ourCategory = any (hasUid itemId) . view itemsDeleted
  allCategories <- use (categories <> categoriesDeleted)
  case find ourCategory allCategories of
    Nothing -> return (Left "item not found in deleted items")
    Just category -> do
      let item = fromJust (find (hasUid itemId) (category^.itemsDeleted))
      let category' = category
            & itemsDeleted %~ deleteFirst (hasUid itemId)
            & items        %~ insertAtGuaranteed pos item
      categories        . each . filtered ourCategory .= category'
      categoriesDeleted . each . filtered ourCategory .= category'
      return (Right ())

restoreTrait :: Uid Item -> Uid Trait -> Int -> Acid.Update GlobalState (Either String ())
restoreTrait itemId traitId pos = do
  let getItems = view (items <> itemsDeleted)
      ourCategory = any (hasUid itemId) . getItems
  allCategories <- use (categories <> categoriesDeleted)
  case find ourCategory allCategories of
    Nothing -> return (Left "item -that the trait belongs to- not found")
    Just category -> do
      let item = fromJust (find (hasUid itemId) (getItems category))
      case (find (hasUid traitId) (item^.prosDeleted),
            find (hasUid traitId) (item^.consDeleted)) of
        (Nothing, Nothing) ->
          return (Left "trait not found in deleted traits")
        (Just trait, _) -> do
          let item' = item
                & prosDeleted %~ deleteFirst (hasUid traitId)
                & pros        %~ insertAtGuaranteed pos trait
          let category' = category
                & items        . each . filtered (hasUid itemId) .~ item'
                & itemsDeleted . each . filtered (hasUid itemId) .~ item'
          categories        . each . filtered ourCategory .= category'
          categoriesDeleted . each . filtered ourCategory .= category'
          return (Right ())
        (_, Just trait) -> do
          let item' = item
                & consDeleted %~ deleteFirst (hasUid traitId)
                & cons        %~ insertAtGuaranteed pos trait
          let category' = category
                & items        . each . filtered (hasUid itemId) .~ item'
                & itemsDeleted . each . filtered (hasUid itemId) .~ item'
          categories        . each . filtered ourCategory .= category'
          categoriesDeleted . each . filtered ourCategory .= category'
          return (Right ())

-- TODO: maybe have a single list of traits with pro/con being signified by
-- something like TraitType? or maybe TraitType could even be a part of the
-- trait itself?

getEdit :: Int -> Acid.Query GlobalState (Edit, EditDetails)
getEdit n = do
  edits <- view pendingEdits
  case find ((== n) . editId . snd) edits of
    Nothing   -> error ("no edit with id " ++ show n)
    Just edit -> return edit

-- | Returns edits in order from latest to earliest.
getEdits
  :: Int            -- ^ Id of latest edit
  -> Int            -- ^ Id of earliest edit
  -> Acid.Query GlobalState [(Edit, EditDetails)]
getEdits m n =
  filter (\(_, d) -> n <= editId d && editId d <= m) <$> view pendingEdits

-- | The edit won't be registered if it's vacuous (see 'isVacuousEdit').
registerEdit
  :: Edit
  -> Maybe IP
  -> UTCTime
  -> Acid.Update GlobalState ()
registerEdit ed ip date = do
  id' <- use editIdCounter
  let details = EditDetails {
        editIP   = ip,
        editDate = date,
        editId   = id' }
  pendingEdits %= ((ed, details):)
  editIdCounter += 1

removePendingEdit :: Int -> Acid.Update GlobalState (Edit, EditDetails)
removePendingEdit n = do
  edits <- use pendingEdits
  case find ((== n) . editId . snd) edits of
    Nothing   -> error ("no edit with id " ++ show n)
    Just edit -> do
      pendingEdits %= deleteFirst ((== n) . editId . snd)
      return edit

removePendingEdits
  :: Int            -- ^ Id of latest edit
  -> Int            -- ^ Id of earliest edit
  -> Acid.Update GlobalState ()
removePendingEdits m n = do
  pendingEdits %= filter (\(_, d) -> editId d < n || m < editId d)

registerAction
  :: Action
  -> Maybe IP
  -> UTCTime
  -> Url                          -- ^ Base URL
  -> Maybe Url                    -- ^ Referrer
  -> Maybe Text                   -- ^ User-agent
  -> Acid.Update GlobalState ()
registerAction act ip date baseUrl ref ua = do
  let details = ActionDetails {
        actionIP        = ip,
        actionDate      = date,
        actionReferrer  = case T.stripPrefix baseUrl <$> ref of
                            Nothing       -> Nothing
                            Just Nothing  -> ExternalReferrer <$> ref
                            Just (Just s) -> Just (InternalReferrer s),
        actionUserAgent = ua }
  actions %= ((act, details) :)

setDirty :: Acid.Update GlobalState ()
setDirty = dirty .= True

unsetDirty :: Acid.Update GlobalState Bool
unsetDirty = dirty <<.= False

makeAcidic ''GlobalState [
  -- queries
  'getGlobalState,
  'getCategories,
  'getCategory, 'getCategoryMaybe,
  'getCategoryByItem,
  'getItem,
  'getTrait,
  -- add
  'addCategory,
  'addItem,
  'addPro, 'addCon,
  -- set
  'setGlobalState,
  'setCategoryTitle, 'setCategoryGroup, 'setCategoryNotes, 'setCategoryStatus,
    'setCategoryProsConsEnabled, 'setCategoryEcosystemEnabled,
    'setCategoryNotesEnabled,
  'setItemName, 'setItemLink, 'setItemGroup, 'setItemKind,
    'setItemDescription, 'setItemNotes, 'setItemEcosystem,
  'setTraitContent,
  -- delete
  'deleteCategory,
  'deleteItem,
  'deleteTrait,
  -- edits
  'getEdit, 'getEdits,
  'registerEdit,
  'removePendingEdit, 'removePendingEdits,
  -- actions
  'registerAction,
  -- other
  'moveItem, 'moveTrait,
  'restoreCategory, 'restoreItem, 'restoreTrait,
  'setDirty, 'unsetDirty
  ]
