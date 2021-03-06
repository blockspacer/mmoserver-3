// Generated by the protocol buffer compiler.  DO NOT EDIT!
// source: common.proto

#ifndef PROTOBUF_common_2eproto__INCLUDED
#define PROTOBUF_common_2eproto__INCLUDED

#include <string>

#include <google/protobuf/stubs/common.h>

#if GOOGLE_PROTOBUF_VERSION < 3001000
#error This file was generated by a newer version of protoc which is
#error incompatible with your Protocol Buffer headers.  Please update
#error your headers.
#endif
#if 3001000 < GOOGLE_PROTOBUF_MIN_PROTOC_VERSION
#error This file was generated by an older version of protoc which is
#error incompatible with your Protocol Buffer headers.  Please
#error regenerate this file with a newer version of protoc.
#endif

#include <google/protobuf/arena.h>
#include <google/protobuf/arenastring.h>
#include <google/protobuf/generated_message_util.h>
#include <google/protobuf/metadata.h>
#include <google/protobuf/repeated_field.h>
#include <google/protobuf/extension_set.h>
#include <google/protobuf/generated_enum_reflection.h>
// @@protoc_insertion_point(includes)

// Internal implementation detail -- do not call these.
void protobuf_AddDesc_common_2eproto();
void protobuf_InitDefaults_common_2eproto();
void protobuf_AssignDesc_common_2eproto();
void protobuf_ShutdownFile_common_2eproto();


enum MESSAGE_OPCODE {
  CLIENT_MESSAGE_LUA_MESSAGE = 2,
  SERVER_MESSAGE_OPCODE_LUA_MESSAGE = 3,
  CLIENT_MESSAGE_OPCODE_MOVE = 4,
  SERVER_MESSAGE_OPCODE_MOVE = 5,
  CLIENT_MESSAGE_OPCODE_STOP_MOVE = 6,
  SERVER_MESSAGE_OPCODE_STOP_MOVE = 7,
  CLIENT_MESSAGE_FORCE_POSITION = 8,
  SERVER_MESSAGE_FORCE_POSITION = 9,
  CLIENT_MESSAGE_OPCODE_TURN_DIRECTION = 10,
  SERVER_MESSAGE_OPCODE_TURN_DIRECTION = 11,
  SERVER_MESSAGE_OPCODE_CREATE_ENTITY = 12,
  SERVER_MESSAGE_OPCODE_DESTROY_ENTITY = 13,
  CLIENT_MESSAGE_OPCODE_CONNECT_REQUEST = 20,
  SERVER_MESSAGE_OPCODE_CONNECT_REPLY = 21,
  CLIENT_MESSAGE_OPCODE_PING = 100,
  SERVER_MESSAGE_OPCODE_PING_BACK = 101,
  CLIENT_MESSAGE_OPCODE_PING_BACK = 102,
  GS_MESSAFE_OPCODE_REGISTER = 10001
};
bool MESSAGE_OPCODE_IsValid(int value);
const MESSAGE_OPCODE MESSAGE_OPCODE_MIN = CLIENT_MESSAGE_LUA_MESSAGE;
const MESSAGE_OPCODE MESSAGE_OPCODE_MAX = GS_MESSAFE_OPCODE_REGISTER;
const int MESSAGE_OPCODE_ARRAYSIZE = MESSAGE_OPCODE_MAX + 1;

const ::google::protobuf::EnumDescriptor* MESSAGE_OPCODE_descriptor();
inline const ::std::string& MESSAGE_OPCODE_Name(MESSAGE_OPCODE value) {
  return ::google::protobuf::internal::NameOfEnum(
    MESSAGE_OPCODE_descriptor(), value);
}
inline bool MESSAGE_OPCODE_Parse(
    const ::std::string& name, MESSAGE_OPCODE* value) {
  return ::google::protobuf::internal::ParseNamedEnum<MESSAGE_OPCODE>(
    MESSAGE_OPCODE_descriptor(), name, value);
}
// ===================================================================


// ===================================================================


// ===================================================================

#if !PROTOBUF_INLINE_NOT_IN_HEADERS
#endif  // !PROTOBUF_INLINE_NOT_IN_HEADERS

// @@protoc_insertion_point(namespace_scope)

#ifndef SWIG
namespace google {
namespace protobuf {

template <> struct is_proto_enum< ::MESSAGE_OPCODE> : ::google::protobuf::internal::true_type {};
template <>
inline const EnumDescriptor* GetEnumDescriptor< ::MESSAGE_OPCODE>() {
  return ::MESSAGE_OPCODE_descriptor();
}

}  // namespace protobuf
}  // namespace google
#endif  // SWIG

// @@protoc_insertion_point(global_scope)

#endif  // PROTOBUF_common_2eproto__INCLUDED
