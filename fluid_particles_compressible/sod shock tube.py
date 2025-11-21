# sod shock tube

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation


N_cells= 200

rho  = np.zeros(N_cells)
m = np.zeros_like(rho)
E = np.zeros_like(rho)

u = np.zeros_like(rho)
p = np.zeros_like(rho)

i = np.asarray(np.arange(0,N_cells))

dx = 1
dt = 0.1

gamma = 1.4

# initialize
left = i<N_cells/2
right = i>=N_cells/2

rho[left] = 1
rho[right] = 0.125

u[left] = 0
u[right] = 0.0

p[left] = 1
p[right] = 0.1

m =  rho*u

def calculate_E(rho, u, p):
    E = p/(gamma - 1) + 1/2*rho*u**2
    return E

def calculate_p(rho,u,E):
    p = (gamma - 1)*(E - 1/2*rho*u**2)
    return p

E = calculate_E(rho, u,p)


state = np.asarray([rho, m, E])

def flux(state):
    U = state

    # unpack
    rho = U[0,:]
    u = U[1,:]/rho
    E = U[2,:]

    p = calculate_p(rho,u, E)

    F = np.asarray([rho*u, rho*u*u + p, u*(E + p)])

    return F

# flux function at edgues
def flux_lax_friedrichs(state, index_offset):

    n = state.shape[1]

    # add ghosts
    U = state; 
    U = np.insert(U, 0, state[:,0], axis=1)
    U = np.insert(U,-1, state[:,-1], axis=1)

    F_no_ghosts = flux(state)
    F = F_no_ghosts
    F = np.insert(F, 0, F_no_ghosts[:,0], axis=1)
    F = np.insert(F,-1, F_no_ghosts[:,-1], axis=1)

    # unpack
    rho = U[0,:]
    u = U[1,:]/rho
    E = U[2,:]

    i = np.arange(1, n+1) + index_offset
    

    lax_fried_flux = 1/2*(F[:, i+1] + F[:,i]) - 1/2*dx/dt*(U[:,i+1] - U[:,i])
    return lax_fried_flux


flux_lax_friedrichs(state,0)

# perform step
ax = plt.plot(i,state[0,:])

max_iterations = 3000
iteration = 0
rho_history = []
time_history = []
t = 0

while iteration< max_iterations:
    state = state - dt/dx*(flux_lax_friedrichs(state, 0) - flux_lax_friedrichs(state, -1) )
    t = t+ dt

    if iteration%20 ==0:
        # unpack
        rho = state[0,:]
        u = state[1,:]/rho
        E = state[2,:]

        p = calculate_p(rho,u, E)
        T = p/rho
        rho_history.append(p)
        time_history.append(t)
    iteration = iteration + 1

    


def animate_solution(time_history, rho_history):
    """
    Uses matplotlib.animation.FuncAnimation to display the evolution of density.
    """
    i = np.arange(0,len(rho_history[0]))

    fig, ax = plt.subplots(figsize=(10, 5))
    line, = ax.plot(i, rho_history[0], color='blue', linewidth=2)
    
    # Setup plot limits and labels
    ax.set_xlim(0, max(i))
    ax.set_ylim(0, max(np.ndarray.flatten(np.asarray(rho_history)))) # Density range from min (0.125) to max (1.0)
    ax.set_xlabel('Position $x$', fontsize=12)
    ax.set_ylabel('Density $\\rho$', fontsize=12)
    ax.set_title('1D Sod Shock Tube Simulation (Lax-Friedrichs)', fontsize=14)
    time_text = ax.text(0.05, 0.9, '', transform=ax.transAxes, fontsize=12)
    ax.grid(True, linestyle=':', alpha=0.6)

    def update(frame):
        """Update function called by FuncAnimation."""
        line.set_ydata(rho_history[frame])
        time_text.set_text(f'Time: {time_history[frame]:.3f}')
        return line, time_text

    # Create the animation. interval is the delay in ms between frames.
    ani = animation.FuncAnimation(
        fig, update, frames=len(rho_history), interval=50, blit=True
    )
    
    # Note: To save the animation, you would need to install ffmpeg
    # e.g., ani.save('sod_shock_tube.gif', writer='pillow')
    plt.show()

animate_solution(time_history, rho_history)







    

