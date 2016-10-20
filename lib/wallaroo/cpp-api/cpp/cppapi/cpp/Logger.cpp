//
// Created by Kevin A. Goldstein R.  on 9/26/16.
//

#include "Logger.hpp"





namespace wallaroo
{

Logger* Logger::_instance = nullptr;








//------------------------------------------------

Logger::Logger ()
{
#if defined(CONSOLE)
  _logger = spdlog::stdout_logger_mt("console");
#else
  _logger = spdlog::basic_logger_mt("basic_logger", "debug_cppapi.log");
#endif
  _logger->set_level(spdlog::level::debug);
}




//------------------------------------------------
Logger::~Logger ()
{
  //delete _logger;
}




//------------------------------------------------
// yeah - this should be trhead safe but... eh...
Logger* Logger::getInstnace ()
{
  if (nullptr == _instance)
  {
    _instance = new Logger();
  }

  return _instance;
}




//------------------------------------------------
std::shared_ptr <spdlog::logger> Logger::getLogger ()
{
  return getInstnace()->_logger;
}


}
