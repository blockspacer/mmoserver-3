import os
import imp
import sys
try:
    import simplejson as json
except ImportError:
    import json

string_types = (str, unicode)

class Configure(dict):
    "Works exactly like a dict"
    def __init__(self, root_path=None, defaults=None):
        dict.__init__(self, defaults or {})
        self.root_path = root_path

    def from_pyfile(self, filename, silent=False):
        """
        Update the values in the config from a python file
        :param filename: the name of config file. This can either be an
                          absolute filename or relative to the root_path
        :param silent: set to 'True' if you want silent failure for missing
                       files
        """
        filename = os.path.join(self.root_path, filename)
        m = imp.new_module("config")
        m.__file__ = filename
        try:
            with open(filename) as config_file:
                exec(compile(config_file.read(), filename, 'exec'), m.__dict__)
        except IOError as e:
            if silent and e.errno in (errno.ENOENT, errno.EISDIR):
                return False
            e.strerror = "Unable to load config file %s"%e.strerror
            raise

        self.from_object(m)
        return True

    def from_object(self, obj):
        """
        Update the values from the given object. An object can be one of the following
        two types:
        -   a string: in this case the object with the name will be import
        -   an actual object reference: use directly
        
        :param obj: an import name or object
        """
        if isinstance(obj, string_types):
            obj = import_string(obj)
        for key in dir(obj):
            self[key] = getattr(obj, key)

    def import_string(self, import_name, silent=False):
        """
        Imports an object base on a string. This is usefull if you want to use import 
        path as endpoints or something similar
        """
        import_name = str(import_name).replace(":",",")
        try:
            try:
                __import__(import_name)
            except ImportError:
                if '.' not in import_name:
                    raise
            else:
                return sys.modules[import_name]

            module_name, obj_name = import_name.rsplit('.', 1)
            try:
                module = __import__(module_name, None, None, [obj_name])
            except ImportError:
                # support importing modules not yet set up by the parent module
                # (or package for that matter)
                module = import_string(module_name)

            try:
                return getattr(module, obj_name)
            except AttributeError as e:
                raise ImportError(e)

        except ImportError as e:
            if not silent:
                reraise(
                    ImportStringError,
                    ImportStringError(import_name, e),
                    sys.exc_info()[2])     

    def from_json(self, filename, silent=False):
        "Update the values in the config file from a json file"
        #filename = os.path.join(self.root_path, filename)

        try:
            with open(filename) as json_file:
                obj = json.loads(json_file.read())
        except IOError as e:
            if silent and e.errno in (errno.ENOENT, errno.EISDIR):
                return False
            e.strerror = 'Unable to load configuration file (%s)' % e.strerror
            raise
        return self.from_mapping(obj)

    def from_mapping(self, *mapping, **kwargs):
        """Updates the config like :meth:`update` ignoring items with non-upper keys.
        """
        mappings = []
        if len(mapping) == 1:
            if hasattr(mapping[0], 'items'):
                mappings.append(mapping[0].items())
            else:
                mappings.append(mapping[0])
        elif len(mapping) > 1:
            raise TypeError(
                'expected at most 1 positional argument, got %d' % len(mapping)
                )
        mappings.append(kwargs.items())
        for mapping in mappings:
            for (key, value) in mapping:
                self[key] = value
        return True


config = Configure()
#from_json = _C.from_json



