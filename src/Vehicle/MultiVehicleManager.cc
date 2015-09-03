/*=====================================================================
 
 QGroundControl Open Source Ground Control Station
 
 (c) 2009 - 2014 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 
 This file is part of the QGROUNDCONTROL project
 
 QGROUNDCONTROL is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 QGROUNDCONTROL is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with QGROUNDCONTROL. If not, see <http://www.gnu.org/licenses/>.
 
 ======================================================================*/

/// @file
///     @author Don Gagne <don@thegagnes.com>

#include "MultiVehicleManager.h"
#include "AutoPilotPlugin.h"
#include "JoystickManager.h"
#include "MAVLinkProtocol.h"
#include "UAS.h"

IMPLEMENT_QGC_SINGLETON(MultiVehicleManager, MultiVehicleManager)

MultiVehicleManager::MultiVehicleManager(QObject* parent) :
    QGCSingleton(parent)
    , _activeVehicleAvailable(false)
    , _parameterReadyVehicleAvailable(false)
    , _activeVehicle(NULL)
    , _offlineWaypointManager(NULL)
{
    QQmlEngine::setObjectOwnership(this, QQmlEngine::CppOwnership);
    qmlRegisterUncreatableType<MultiVehicleManager>("QGroundControl.MultiVehicleManager", 1, 0, "MultiVehicleManager", "Reference only");
}

MultiVehicleManager::~MultiVehicleManager()
{

}

bool MultiVehicleManager::notifyHeartbeatInfo(LinkInterface* link, int vehicleId, mavlink_heartbeat_t& heartbeat)
{
    if (!_vehicleMap.contains(vehicleId) && !_ignoreVehicleIds.contains(vehicleId)) {
        if (vehicleId == MAVLinkProtocol::instance()->getSystemId()) {
            qgcApp()->showToolBarMessage(QString("Warning: A vehicle is using the same system id as QGroundControl: %1").arg(vehicleId));
        }
        
        QSettings settings;
        bool mavlinkVersionCheck = settings.value("VERSION_CHECK_ENABLED", true).toBool();
        if (mavlinkVersionCheck && heartbeat.mavlink_version != MAVLINK_VERSION) {
            _ignoreVehicleIds += vehicleId;
            qgcApp()->showToolBarMessage(QString("The MAVLink protocol version on vehicle #%1 and QGroundControl differ! "
                                                 "It is unsafe to use different MAVLink versions. "
                                                 "QGroundControl therefore refuses to connect to vehicle #%1, which sends MAVLink version %2 (QGroundControl uses version %3).").arg(vehicleId).arg(heartbeat.mavlink_version).arg(MAVLINK_VERSION));
            return false;
        }
        
        Vehicle* vehicle = new Vehicle(link, vehicleId, (MAV_AUTOPILOT)heartbeat.autopilot);
        
        if (!vehicle) {
            qWarning() << "New Vehicle allocation failed";
            return false;
        }
        
        connect(vehicle, &Vehicle::allLinksDisconnected, this, &MultiVehicleManager::_deleteVehiclePhase1);
        connect(vehicle->autopilotPlugin(), &AutoPilotPlugin::pluginReadyChanged, this, &MultiVehicleManager::_autopilotPluginReadyChanged);

        _vehicleMap[vehicleId] = vehicle;
        
        emit vehicleAdded(vehicle);
        
        setActiveVehicle(vehicle);
    }
    
    return true;
}

/// This slot is connected to the Vehicle::allLinksDestroyed signal such that the Vehicle is deleted
/// and all other right things happen when the Vehicle goes away.
void MultiVehicleManager::_deleteVehiclePhase1(void)
{
    Vehicle* vehicle = dynamic_cast<Vehicle*>(sender());
    if (!vehicle) {
        qWarning() << "Dynamic cast failed!";
        return;
    }
    
    _vehicleBeingDeleted = vehicle;

    // Remove from map
    bool found;
    foreach(int id, _vehicleMap.keys()) {
        if (_vehicleMap[id] == _vehicleBeingDeleted) {
            _vehicleMap.remove(id);
            found = true;
            break;
        }
    }
    if (!found) {
        qWarning() << "Vehicle not found in map!";
    }
    
    // Disconnect the vehicle from the uas
    vehicle->uas()->clearVehicle();
    
    // Disconnect joystick
    Joystick* joystick = JoystickManager::instance()->activeJoystick();
    if (joystick) {
        joystick->stopPolling();
    }
    
    // First we must signal that a vehicle is no longer available.
    _activeVehicleAvailable = false;
    _parameterReadyVehicleAvailable = false;
    emit activeVehicleAvailableChanged(false);
    emit parameterReadyVehicleAvailableChanged(false);
    emit vehicleRemoved(vehicle);
    
    // We must let the above signals flow through the system as well as get back to the main loop event queue
    // before we can actually delete the Vehicle. The reason is that Qml may be holding on the references to it.
    // Even though the above signals should unload any Qml which has references, that Qml will not be destroyed
    // until we get back to the main loop. So we set a short timer which will then fire after Qt has finished
    // doing all of its internal nastiness to clean up the Qml. This works for both the normal running case
    // as well as the unit testing case whichof course has a different signal flow!
    QTimer::singleShot(20, this, &MultiVehicleManager::_deleteVehiclePhase2);
}

void MultiVehicleManager::_deleteVehiclePhase2  (void)
{
    /// Qml has been notified of vehicle about to go away and should be disconnected from it by now.
    /// This means we can now clear the active vehicle property and delete the Vehicle for real.
    
    Vehicle* newActiveVehicle = NULL;
    if (_vehicleMap.count()) {
        newActiveVehicle = _vehicleMap.first();
    }
    
    _activeVehicle = newActiveVehicle;
    emit activeVehicleChanged(newActiveVehicle);
    
    if (_activeVehicle) {
        emit activeVehicleAvailableChanged(true);
        if (_activeVehicle->autopilotPlugin()->pluginReady()) {
            emit parameterReadyVehicleAvailableChanged(true);
        }
    }
    
    _vehicleBeingDeleted->deleteLater();
}

void MultiVehicleManager::setActiveVehicle(Vehicle* vehicle)
{
    if (vehicle != _activeVehicle) {
        if (_activeVehicle) {
            // Disconnect joystick
            Joystick* joystick = JoystickManager::instance()->activeJoystick();
            if (joystick) {
                joystick->stopPolling();
            }
                
            // The sequence of signals is very important in order to not leave Qml elements connected
            // to a non-existent vehicle.
            
            // First we must signal that there is no active vehicle available. This will disconnect
            // any existing ui from the currently active vehicle.
            _activeVehicleAvailable = false;
            _parameterReadyVehicleAvailable = false;
            emit activeVehicleAvailableChanged(false);
            emit parameterReadyVehicleAvailableChanged(false);
        }
        
        // See explanation in _deleteVehiclePhase1
        _vehicleBeingSetActive = vehicle;
        QTimer::singleShot(20, this, &MultiVehicleManager::_setActiveVehiclePhase2);
    }
}

void MultiVehicleManager::_setActiveVehiclePhase2(void)
{
    // Now we signal the new active vehicle
    _activeVehicle = _vehicleBeingSetActive;
    emit activeVehicleChanged(_activeVehicle);
    
    // And finally vehicle availability
    if (_activeVehicle) {
        _activeVehicleAvailable = true;
        emit activeVehicleAvailableChanged(true);
        
        if (_activeVehicle->autopilotPlugin()->pluginReady()) {
            _parameterReadyVehicleAvailable = true;
            emit parameterReadyVehicleAvailableChanged(true);
        }
    }
}

void MultiVehicleManager::_autopilotPluginReadyChanged(bool pluginReady)
{
    AutoPilotPlugin* autopilot = dynamic_cast<AutoPilotPlugin*>(sender());
    
    if (!autopilot) {
        qWarning() << "Dynamic cast failed!";
        return;
    }
    
    if (autopilot->vehicle() == _activeVehicle) {
        // Connect joystick
        Joystick* joystick = JoystickManager::instance()->activeJoystick();
        if (joystick && joystick->enabled()) {
            joystick->startPolling();
        }
        
        _parameterReadyVehicleAvailable = pluginReady;
        emit parameterReadyVehicleAvailableChanged(pluginReady);
    }
}

void MultiVehicleManager::setHomePositionForAllVehicles(double lat, double lon, double alt)
{
    foreach (Vehicle* vehicle, _vehicleMap) {
        vehicle->uas()->setHomePosition(lat, lon, alt);
    }
}

UASWaypointManager* MultiVehicleManager::activeWaypointManager(void)
{
    if (_activeVehicle) {
        return _activeVehicle->uas()->getWaypointManager();
    }
    
    if (!_offlineWaypointManager) {
        _offlineWaypointManager = new UASWaypointManager(NULL, NULL);
    }
    return _offlineWaypointManager;
}

QList<Vehicle*> MultiVehicleManager::vehicles(void)
{
    QList<Vehicle*> list;
    
    foreach (Vehicle* vehicle, _vehicleMap) {
        list += vehicle;
    }
    
    return list;
}

QVariantList MultiVehicleManager::vehiclesAsVariants(void)
{
    QVariantList list;
    
    foreach (Vehicle* vehicle, _vehicleMap) {
        list += QVariant::fromValue(vehicle);
    }
    
    return list;
}

void MultiVehicleManager::saveSetting(const QString &name, const QString& value)
{
    QSettings settings;
    settings.setValue(name, value);
}

QString MultiVehicleManager::loadSetting(const QString &name, const QString& defaultValue)
{
    QSettings settings;
    return settings.value(name, defaultValue).toString();
}
