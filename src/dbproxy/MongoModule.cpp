#include "MongoModule.h"
#include "message/dbmongo.pb.h"
#include "IDBProxy.h"

MongoModule::MongoModule():m_dbconn(true)
{
}

MongoModule::~MongoModule()
{
}

bool MongoModule::Init()
{
	// 在这里初始化
	mongo::Status y = mongo::client::initialize();
	if (!y.isOK())
	{
		return false;
	}

	auto mongoConfig = ServerConfigure::Instance()->GetDBConfig();
	m_dbAddress = mongoConfig.Address;
	m_dbName = mongoConfig.DBName;
	m_dbUser = mongoConfig.UserName;
	m_dbPwd = mongoConfig.UserPassword;

	std::string err;
	if (!m_dbconn.connect(m_dbAddress, err))
	{
		_xerror("Failed connect mongo of address %s, error is %s", m_dbAddress.c_str(), err.c_str());
		return false;
	}


	try
	{
		bool ret = m_dbconn.auth(m_dbName, m_dbUser, m_dbPwd, err, true);
		if (!ret)
		{
			_xerror("Failed auth mongo of dbname %s with user %s pwd %s", m_dbName.c_str(), m_dbUser.c_str(), m_dbPwd.c_str());
			return false;
		}
	}
	catch (mongo::DBException &e)
	{
		_xerror("Failed auth mongo of errcode %d and error message id %s", e.getCode(), e.toString().c_str());
		return false;
	}
	
	m_dbname = m_dbName;
	m_dbname += ".";
	return true;
}


void MongoModule::InsertOpreation(SERVERID src, const char * message, const DATA_LENGTH_TYPE messageLength)
{
	InsertDocRequest request;
	if (!request.ParseFromArray(message, messageLength))
	{
		_xerror("Failed parse InsertDocRequest of messageLength %d", messageLength);
		return;
	}
	std::string ns(m_dbname);
	ns += request.collection();
	
	std::string doc = request.doc();
	mongo::BSONObj doc_bson(doc.data());

	_info("InsertOpreation of bson doc start %s", doc_bson.jsonString().c_str());
	bool success_flag = true;
	try
	{
		m_dbconn.insert(ns, doc_bson);
	}
	catch (mongo::DBException &f)
	{
		success_flag = false;
		_xerror("Failed insert of errcode %d and error message %s", f.getCode(), f.toString().c_str());
	}
	_info("InsertOpreation of bson doc end");

	InsertDocReply reply;
	reply.set_callback_id(request.callback_id());
	reply.set_status(success_flag);

	//GlobalDBServerModule->SendResultBack(src, INNER_MESSAGE_TYPE_DB_INSERT_DOC_REPLY, &reply);
	GlobalDBServerModule->SendResultBack(src, dbproxy::DBCLIENT_INSERT_DOC_REPLY, &reply);
}

void MongoModule::UpdateOpearation(SERVERID src, const char * message, const DATA_LENGTH_TYPE messageLength)
{
	UpdateDocRequest request;
	if (!request.ParseFromArray(message, messageLength))
	{
		_xerror("MongoModule::UpdateOpearation request ParseFromArray error %d, Reason is %s", messageLength, request.Utf8DebugString().c_str());
		return;
	}
	std::string ns(m_dbname);
	ns += request.collection();
	mongo::BSONObj query(request.query().data());
	mongo::BSONObj fields(request.fields().data());
	bool upsert(request.upsert());
	bool multi(request.multi());
	_info("UpdateOpearation of bson doc start %s, %s", query.jsonString().c_str(), fields.jsonString().c_str());
	bool updateFlag = true;
	try
	{
		m_dbconn.update(ns, query, fields, upsert, multi);
	}
	catch (mongo::DBException &f)
	{
		updateFlag = false;
		_xerror("Failed update of errcode %d and error message %s", f.getCode(), f.toString().c_str());
	}
	_info("UpdateOpearation of bson doc end");
	UpdateDocReply reply;
	reply.set_status(updateFlag);
	reply.set_callback_id(request.callback_id());

	//GlobalDBServerModule->SendResultBack(src, INNER_MESSAGE_TYPE_DB_UPDATE_DOC_REPLY, &reply);
	GlobalDBServerModule->SendResultBack(src, dbproxy::DBCLIENT_UPDATE_DOC_REPLY, &reply);
}

void MongoModule::FindOneOperation(SERVERID src, const char * message, const DATA_LENGTH_TYPE messageLength)
{
	//auto oid = mongo::OID::gen();
	//auto ooid = oid.toString();
	//auto cc = mongo::OID(ooid);
	//if (oid == cc)
	//{
	//	_info("a");
	//}
	FindDocRequest request;
	if (!request.ParseFromArray(message, messageLength))
	{
		_xerror("MongoModule::FindOneOperation request ParseFromArray error");
		return;
	}
	std::string ns(m_dbname);
	ns += request.collection();
	mongo::BSONObj query(request.query().data());
	//mongo::Query query(request.query().data());
	mongo::BSONObj fields(request.fields().data());
	_info("FindOneOperation of bson doc start %s, %s", query.jsonString().c_str(), fields.jsonString().c_str());
	bool findOneFlag = true;
	mongo::BSONObj ret;
	try
	{
		ret = m_dbconn.findOne(ns, query, &fields);
	}
	catch (mongo::DBException &f)
	{
		findOneFlag = false;
		_xerror("Failed FindOneOperation of errcode %d and error message %s", f.getCode(), f.toString().c_str());
	}

	std::string ret_with0(ret.objdata(), ret.objsize());
	_info("FindOneOperation of bson doc end");
	FindDocReply reply;
	reply.add_docs(ret_with0);
	reply.set_callback_id(request.callback_id());
	reply.set_status(findOneFlag);
	GlobalDBServerModule->SendResultBack(src, dbproxy::DBCLIENT_FIND_ONE_DOC_REPLY, &reply);
}

void MongoModule::FindNOperation(SERVERID src, const char * message, const DATA_LENGTH_TYPE messageLength)
{
	FindDocRequest request;
	if (!request.ParseFromArray(message, messageLength))
	{
		_xerror("MongoModule::FindOneOperation request ParseFromArray error");
		return;
	}
	std::string ns(m_dbname);
	ns += request.collection();
	mongo::BSONObj query(request.query().data());
	mongo::BSONObj fields(request.fields().data());
	_info("FindNOperation of bson doc start %s, %s", query.jsonString().c_str(), fields.jsonString().c_str());
	bool findOneFlag = true;
	//mongo::BSONObj ret;
	std::vector<mongo::BSONObj> ret;
	try
	{
		m_dbconn.findN(ret, ns, query, 50, 0, &fields);
	}
	catch (mongo::DBException &f)
	{
		findOneFlag = false;
		_xerror("Failed FindNOperation of errcode %d and error message %s", f.getCode(), f.toString().c_str());
	}

	FindDocReply reply;
	for (auto it = ret.begin(); it != ret.end(); ++it)
	{
		std::string tmp(it->objdata(), it->objsize());
		reply.add_docs(tmp);
	}
	
	reply.set_callback_id(request.callback_id());
	reply.set_status(findOneFlag);
	GlobalDBServerModule->SendResultBack(src, dbproxy::DBCLIENT_FIND_N_DOC_REPLY, &reply);
}

void MongoModule::FindAndModifyOperation(SERVERID src, const char * message, const DATA_LENGTH_TYPE messageLength)
{
	FindAndModifyDocRequest request;
	if (!request.ParseFromArray(message, messageLength))
	{
		_xerror("MongoModule::FindOneOperation request ParseFromArray error");
		return;
	}

	std::string ns(m_dbname);
	ns += request.collection();
	mongo::BSONObj query(request.query().data());
	mongo::BSONObj update(request.update().data());
	bool upsert(request.upsert());
	bool returnNew(request.New());
	mongo::BSONObj fields(request.fields().data());
	mongo::BSONObj sort;

	bool findAndModifyFlag = true;

	mongo::BSONObj ret;
	try
	{
		ret = m_dbconn.findAndModify( ns, query, update, upsert, returnNew, sort, fields);
	}
	catch (mongo::DBException &f)
	{
		findAndModifyFlag = false;
		_xerror("Failed findAndModifyFlag of errcode %d and error message %s", f.getCode(), f.toString().c_str());
	}

	FindAndModifyDocReply reply;
	reply.set_callback_id(request.callback_id());
	reply.set_status(findAndModifyFlag);
	reply.set_doc(ret.objdata(), ret.objsize());

	GlobalDBServerModule->SendResultBack(src, dbproxy::DBCLIENT_FIND_AND_MODIFY_DOC_REPLY, &reply);
}
