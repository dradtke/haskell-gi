
module GI.API
    ( API(..)
    , Name(..)
    , Constant(..)
    , Arg(..)
    , Callable(..)
    , Function(..)
    , Signal(..)
    , Property(..)
    , Field(..)
    , Struct(..)
    , Callback(..)
    , Interface(..)
    , Object(..)
    , Enumeration(..)
    , Flags (..)
    , loadAPI
    ) where

import Data.Word

import GI.Internal.Types
import GI.Internal.ArgInfo
import GI.Internal.BaseInfo
import GI.Internal.CallableInfo
import GI.Internal.ConstantInfo
import GI.Internal.EnumInfo
import GI.Internal.FieldInfo
import GI.Internal.FunctionInfo
import GI.Internal.InterfaceInfo
import GI.Internal.ObjectInfo
import GI.Internal.PropertyInfo
import GI.Internal.StructInfo
import GI.Internal.Typelib (getInfos, load)
import GI.Internal.UnionInfo
import GI.Type
import GI.Value

data Name = Name { namespace :: String, name :: String }
    deriving Show

getName :: BaseInfoClass bi => bi -> Name
getName bi =
   let namespace = baseInfoNamespace $ baseInfo bi
       name = baseInfoName $ baseInfo bi
    in Name namespace name

data Constant = Constant {
    constValue :: Value }
    deriving Show

toConstant :: ConstantInfo -> Constant
toConstant ci =
    let typeInfo = constantInfoType ci
        arg = constantInfoValue ci
        value = fromArgument typeInfo arg
     in Constant value

data Enumeration = Enumeration {
    enumValues :: [(String, Word64)] }
    deriving Show

toEnumeration :: EnumInfo -> Enumeration
toEnumeration ei = Enumeration $
    (map (\vi -> (baseInfoName . baseInfo $ vi, valueInfoValue vi))
        (enumInfoValues ei))

data Flags = Flags Enumeration
    deriving Show

toFlags :: EnumInfo -> Flags
toFlags ei = let enum = toEnumeration ei
              in Flags enum

data Arg = Arg {
    argName :: String,
    argType :: Type,
    direction :: Direction,
    scope :: Scope,
    transfer :: Transfer }
    deriving Show

toArg :: ArgInfo -> Arg
toArg ai =
   Arg (baseInfoName . baseInfo $ ai)
        (typeFromTypeInfo . argInfoType $ ai)
        (argInfoDirection ai)
        (argInfoScope ai)
        (argInfoOwnershipTransfer ai)

data Callable = Callable {
    returnType :: Type,
    returnMayBeNull :: Bool,
    returnTransfer :: Transfer,
    returnAttributes :: [(String, String)],
    args :: [Arg] }
    deriving Show

toCallable :: CallableInfo -> Callable
toCallable ci =
    let returnType = callableInfoReturnType ci
        argType = typeFromTypeInfo returnType
        ais = callableInfoArgs ci
        in Callable argType
               (callableInfoMayReturnNull ci)
               (callableInfoCallerOwns ci)
               (callableInfoReturnAttributes ci)
               (map toArg ais)

data Function = Function {
    fnSymbol :: String,
    fnCallable :: Callable }
    deriving Show

toFunction :: FunctionInfo -> Function
toFunction fi =
     let ci = fromBaseInfo (baseInfo fi) :: CallableInfo
      in Function (functionInfoSymbol fi) (toCallable ci)

data Signal = Signal
    deriving Show

toSignal :: SignalInfo -> Signal
toSignal _si = error "fixme"

data Property = Property {
    propName :: String,
    propType :: Type,
    propFlags :: [ParamFlag] }
    deriving Show

toProperty :: PropertyInfo -> Property
toProperty pi =
    Property (baseInfoName $ baseInfo pi)
        (typeFromTypeInfo $ propertyInfoType pi)
        (propertyInfoFlags pi)

data Field = Field {
    fieldName :: String,
    fieldType :: Type,
    fieldFlags :: [FieldInfoFlag] }
    deriving Show

toField :: FieldInfo -> Field
toField fi =
    Field (baseInfoName . baseInfo $ fi)
        (typeFromTypeInfo $ fieldInfoType fi)
        (fieldInfoFlags fi)

data Struct = Struct {
    fields :: [Field] }
    deriving Show

toStruct :: StructInfo -> Struct
toStruct si = Struct $ map toField $ structInfoFields si

-- XXX: Capture alignment and method info.

data Union = Union {
    unionFields :: [Field] }
    deriving Show

toUnion :: UnionInfo -> Union
toUnion ui = Union $ map toField $ unionInfoFields ui

-- XXX
data Callback = Callback Callable
    deriving Show

toCallback = Callback . toCallable

data Interface = Interface {
    ifMethods :: [(Name, Function)],
    ifConstants :: [(Name, Constant)],
    ifProperties :: [Property] }
    deriving Show

toInterface :: InterfaceInfo -> Interface
toInterface ii = Interface
        (map
         (\mi -> (getName mi, toFunction mi)) $
         interfaceInfoMethods $ ii)
        (map
         (\ci -> (getName ci, toConstant ci)) $
         interfaceInfoConstants ii)
        (map toProperty $ interfaceInfoProperties $ ii)

data Object = Object {
    objFields :: [Field],
    objMethods :: [Function],
    -- objSignals :: [Signal],
    objProperties :: [Property] }
    deriving Show

toObject :: ObjectInfo -> Object
toObject oi = Object
        (map toField $ objectInfoFields oi)
        (map toFunction $ objectInfoMethods oi)
        (map toProperty $ objectInfoProperties oi)

data API
    = APIConst Constant
    | APIFunction Function
    | APICallback Callback
    -- XXX: These plus APIUnion should have their gTypes exposed (via a
    -- binding of GIRegisteredTypeInfo.
    | APIEnum Enumeration
    | APIFlags Flags
    | APIInterface Interface
    | APIObject Object
    | APIStruct Struct
    | APIUnion Union
    deriving Show

toAPI :: BaseInfoClass bi => bi -> (Name, API)
toAPI i = (getName bi, toAPI' (baseInfoType i) bi)
    where

    bi = baseInfo i

    toAPI' InfoTypeConstant = convert APIConst toConstant
    toAPI' InfoTypeEnum = convert APIEnum toEnumeration
    toAPI' InfoTypeFlags = convert APIFlags toFlags
    toAPI' InfoTypeFunction = convert APIFunction toFunction
    toAPI' InfoTypeCallback = convert APICallback toCallback
    toAPI' InfoTypeStruct = convert APIStruct toStruct
    toAPI' InfoTypeUnion = convert APIUnion toUnion
    toAPI' InfoTypeObject = convert APIObject toObject
    toAPI' InfoTypeInterface = convert APIInterface toInterface
    toAPI' it = error $ "not expecting a " ++ show it

    convert fa fb bi = fa $ fb $ fromBaseInfo bi

loadAPI :: String -> IO [(Name, API)]
loadAPI name = do
    lib <- load name Nothing
    infos <- getInfos lib
    -- XXX: Work out what to do with boxed types.
    return $ map toAPI $ filter (\i -> baseInfoType i /= InfoTypeBoxed) infos

